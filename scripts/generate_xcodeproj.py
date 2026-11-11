#!/usr/bin/env python3
"""
Deterministic Xcode Project (.xcodeproj) Generator for APEX OS iOS + WidgetKit + watchOS.
Enables opening ios_app/APEX_iOS.xcodeproj directly in Xcode (with Automatic Signing on free/paid Apple ID)
without requiring Homebrew or xcodegen.
"""

import hashlib
import os
from pathlib import Path
from typing import Dict, Optional


def uid(seed: str) -> str:
    return hashlib.sha1(seed.encode("utf-8")).hexdigest()[:24].upper()


def generate() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    ios_dir = repo_root / "ios_app"
    xcodeproj = ios_dir / "APEX_iOS.xcodeproj"
    schemes_dir = xcodeproj / "xcshareddata" / "xcschemes"
    xcodeproj.mkdir(parents=True, exist_ok=True)
    schemes_dir.mkdir(parents=True, exist_ok=True)

    main_swift_files = sorted(
        p.name
        for p in ios_dir.glob("*.swift")
        if p.name != "generate_ios_icon.swift"
    )
    widget_swift_files = [
        "ApexSharedTypes.swift",
        "Widgets/ApexWidgetIntents.swift",
        "Widgets/ApexWidgets.swift",
    ]
    watch_swift_files = [
        "ApexSharedTypes.swift",
        "Watch/APEXWatchApp.swift",
    ]

    # File References
    file_refs = []
    build_files = []
    main_sources = []
    widget_sources = []
    watch_sources = []
    main_resources = []

    def add_file_ref(path: str, name: Optional[str] = None, file_type: Optional[str] = None, expl_type: Optional[str] = None) -> str:
        fid = uid(f"fileref:{path}")
        disp = name or os.path.basename(path)
        type_field = f"lastKnownFileType = {file_type};" if file_type else f"explicitFileType = {expl_type}; includeInIndex = 0;"
        file_refs.append(f"\t\t{fid} /* {disp} */ = {{isa = PBXFileReference; {type_field} path = \"{path}\"; sourceTree = \"<group>\"; }};")
        return fid

    def add_build_file(fid: str, target_tag: str, disp: str, settings: str = "") -> str:
        bid = uid(f"buildfile:{target_tag}:{fid}")
        s_str = f" settings = {{{settings}; }};" if settings else ""
        build_files.append(f"\t\t{bid} /* {disp} in {target_tag} */ = {{isa = PBXBuildFile; fileRef = {fid} /* {disp} */;{s_str} }};")
        return bid

    swift_ref_map: Dict[str, str] = {}
    for fname in main_swift_files:
        fid = add_file_ref(fname, fname, "sourcecode.swift")
        swift_ref_map[fname] = fid
        main_sources.append(add_build_file(fid, "APEX_iOS_Sources", fname))

    for wpath in widget_swift_files:
        fid = swift_ref_map.get(wpath) or add_file_ref(wpath, os.path.basename(wpath), "sourcecode.swift")
        swift_ref_map[wpath] = fid
        widget_sources.append(add_build_file(fid, "APEXWidgets_Sources", os.path.basename(wpath)))

    for wp in watch_swift_files:
        fid = swift_ref_map.get(wp) or add_file_ref(wp, os.path.basename(wp), "sourcecode.swift")
        swift_ref_map[wp] = fid
        watch_sources.append(add_build_file(fid, "APEXWatch_Sources", os.path.basename(wp)))

    assets_fid = add_file_ref("Assets.xcassets", "Assets.xcassets", "folder.assetcatalog")
    main_resources.append(add_build_file(assets_fid, "APEX_iOS_Resources", "Assets.xcassets"))

    info_fid = add_file_ref("Info.plist", "Info.plist", "text.plist.xml")
    ent_fid = add_file_ref("APEX_iOS.entitlements", "APEX_iOS.entitlements", "text.plist.entitlements")
    widget_info_fid = add_file_ref("Widgets/Info.plist", "Widgets/Info.plist", "text.plist.xml")
    watch_info_fid = add_file_ref("Watch/Info.plist", "Watch/Info.plist", "text.plist.xml")

    app_prod_fid = add_file_ref("APEX_iOS.app", "APEX_iOS.app", expl_type="wrapper.application")
    widget_prod_fid = add_file_ref("APEXWidgets.appex", "APEXWidgets.appex", expl_type="wrapper.app-extension")
    watch_prod_fid = add_file_ref("APEXWatch.app", "APEXWatch.app", expl_type="wrapper.application")

    # Change product fileRefs to BUILT_PRODUCTS_DIR
    file_refs = [
        r.replace('sourceTree = "<group>";', 'sourceTree = BUILT_PRODUCTS_DIR;')
        if ("APEX_iOS.app" in r or "APEXWidgets.appex" in r or "APEXWatch.app" in r) and "explicitFileType" in r
        else r
        for r in file_refs
    ]

    embed_widget_bid = add_build_file(widget_prod_fid, "EmbedExtensions", "APEXWidgets.appex", "ATTRIBUTES = (RemoveHeadersOnCopy, )")
    embed_watch_bid = add_build_file(watch_prod_fid, "EmbedWatch", "APEXWatch.app", "ATTRIBUTES = (RemoveHeadersOnCopy, )")

    # IDs
    root_obj_id = uid("project")
    main_group_id = uid("group:main")
    sources_group_id = uid("group:ios_app")
    widgets_group_id = uid("group:widgets")
    watch_group_id = uid("group:watch")
    products_group_id = uid("group:products")

    t_main_id = uid("target:APEX_iOS")
    t_widget_id = uid("target:APEXWidgets")
    t_watch_id = uid("target:APEXWatch")

    dep_widget_proxy = uid("proxy:widget")
    dep_widget_id = uid("dep:widget")
    dep_watch_proxy = uid("proxy:watch")
    dep_watch_id = uid("dep:watch")

    ph_main_sources = uid("phase:main:sources")
    ph_main_res = uid("phase:main:resources")
    ph_embed_ext = uid("phase:main:embed_ext")
    ph_embed_watch = uid("phase:main:embed_watch")
    ph_widget_sources = uid("phase:widget:sources")
    ph_watch_sources = uid("phase:watch:sources")

    cfg_proj_list = uid("cfglist:proj")
    cfg_proj_dbg = uid("cfg:proj:dbg")
    cfg_proj_rel = uid("cfg:proj:rel")

    cfg_main_list = uid("cfglist:main")
    cfg_main_dbg = uid("cfg:main:dbg")
    cfg_main_rel = uid("cfg:main:rel")

    cfg_wid_list = uid("cfglist:wid")
    cfg_wid_dbg = uid("cfg:wid:dbg")
    cfg_wid_rel = uid("cfg:wid:rel")

    cfg_wat_list = uid("cfglist:wat")
    cfg_wat_dbg = uid("cfg:wat:dbg")
    cfg_wat_rel = uid("cfg:wat:rel")

    sources_children = "\n".join(f"\t\t\t\t{swift_ref_map[n]} /* {n} */," for n in main_swift_files)
    widget_children = "\n".join(f"\t\t\t\t{swift_ref_map[w]} /* {w} */," for w in ["Widgets/ApexWidgetIntents.swift", "Widgets/ApexWidgets.swift"])
    watch_children = f"\t\t\t\t{swift_ref_map['Watch/APEXWatchApp.swift']} /* Watch/APEXWatchApp.swift */,\n\t\t\t\t{watch_info_fid} /* Watch/Info.plist */,"
    build_files_str = "\n".join(build_files)
    file_refs_str = "\n".join(file_refs)
    main_resources_str = "\n".join(f"\t\t\t\t{r}," for r in main_resources)
    main_sources_str = "\n".join(f"\t\t\t\t{b}," for b in main_sources)
    widget_sources_str = "\n".join(f"\t\t\t\t{b}," for b in widget_sources)
    watch_sources_str = "\n".join(f"\t\t\t\t{b}," for b in watch_sources)

    pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_files_str}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
\t\t{dep_widget_proxy} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {root_obj_id} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {t_widget_id};
\t\t\tremoteInfo = APEXWidgets;
\t\t}};
\t\t{dep_watch_proxy} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {root_obj_id} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {t_watch_id};
\t\t\tremoteInfo = APEXWatch;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
\t\t{ph_embed_ext} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{embed_widget_bid} /* APEXWidgets.appex in EmbedExtensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{ph_embed_watch} /* Embed Watch Content */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "$(CONTENTS_FOLDER_PATH)/Watch";
\t\t\tdstSubfolderSpec = 16;
\t\t\tfiles = (
\t\t\t\t{embed_watch_bid} /* APEXWatch.app in EmbedWatch */,
\t\t\t);
\t\t\tname = "Embed Watch Content";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
{file_refs_str}
/* End PBXFileReference section */

/* Begin PBXGroup section */
\t\t{main_group_id} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{sources_group_id} /* APEX_iOS */,
\t\t\t\t{widgets_group_id} /* Widgets */,
\t\t\t\t{watch_group_id} /* Watch */,
\t\t\t\t{products_group_id} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{sources_group_id} /* APEX_iOS */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{sources_children}
\t\t\t\t{assets_fid} /* Assets.xcassets */,
\t\t\t\t{info_fid} /* Info.plist */,
\t\t\t\t{ent_fid} /* APEX_iOS.entitlements */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{widgets_group_id} /* Widgets */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{widget_children}
\t\t\t\t{widget_info_fid} /* Widgets/Info.plist */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{watch_group_id} /* Watch */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{watch_children}
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{products_group_id} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_prod_fid} /* APEX_iOS.app */,
\t\t\t\t{widget_prod_fid} /* APEXWidgets.appex */,
\t\t\t\t{watch_prod_fid} /* APEXWatch.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{t_main_id} /* APEX_iOS */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_main_list} /* Build configuration list for PBXNativeTarget "APEX_iOS" */;
\t\t\tbuildPhases = (
\t\t\t\t{ph_main_sources} /* Sources */,
\t\t\t\t{ph_main_res} /* Resources */,
\t\t\t\t{ph_embed_ext} /* Embed Foundation Extensions */,
\t\t\t\t{ph_embed_watch} /* Embed Watch Content */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{dep_widget_id} /* PBXTargetDependency */,
\t\t\t\t{dep_watch_id} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = APEX_iOS;
\t\t\tproductName = APEX_iOS;
\t\t\tproductReference = {app_prod_fid} /* APEX_iOS.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
\t\t{t_widget_id} /* APEXWidgets */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_wid_list} /* Build configuration list for PBXNativeTarget "APEXWidgets" */;
\t\t\tbuildPhases = (
\t\t\t\t{ph_widget_sources} /* Sources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = APEXWidgets;
\t\t\tproductName = APEXWidgets;
\t\t\tproductReference = {widget_prod_fid} /* APEXWidgets.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
\t\t{t_watch_id} /* APEXWatch */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_wat_list} /* Build configuration list for PBXNativeTarget "APEXWatch" */;
\t\t\tbuildPhases = (
\t\t\t\t{ph_watch_sources} /* Sources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = APEXWatch;
\t\t\tproductName = APEXWatch;
\t\t\tproductReference = {watch_prod_fid} /* APEXWatch.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{root_obj_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t}};
\t\t\tbuildConfigurationList = {cfg_proj_list} /* Build configuration list for PBXProject "APEX_iOS" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group_id};
\t\t\tproductRefGroup = {products_group_id} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{t_main_id} /* APEX_iOS */,
\t\t\t\t{t_widget_id} /* APEXWidgets */,
\t\t\t\t{t_watch_id} /* APEXWatch */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{ph_main_res} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{main_resources_str}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{ph_main_sources} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{main_sources_str}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{ph_widget_sources} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{widget_sources_str}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{ph_watch_sources} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{watch_sources_str}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
\t\t{dep_widget_id} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {t_widget_id} /* APEXWidgets */;
\t\t\ttargetProxy = {dep_widget_proxy} /* PBXContainerItemProxy */;
\t\t}};
\t\t{dep_watch_id} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {t_watch_id} /* APEXWatch */;
\t\t\ttargetProxy = {dep_watch_proxy} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
\t\t{cfg_proj_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{cfg_proj_rel} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 3;
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{cfg_main_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = APEX_iOS.entitlements;
\t\t\t\tINFOPLIST_FILE = Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tOTHER_LDFLAGS = (
\t\t\t\t\t"-weak_framework",
\t\t\t\t\tFoundationModels,
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = club.apex.lifemaxx.ios;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{cfg_main_rel} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = APEX_iOS.entitlements;
\t\t\t\tINFOPLIST_FILE = Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tOTHER_LDFLAGS = (
\t\t\t\t\t"-weak_framework",
\t\t\t\t\tFoundationModels,
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = club.apex.lifemaxx.ios;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{cfg_wid_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tINFOPLIST_FILE = Widgets/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = club.apex.lifemaxx.ios.widgets;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{cfg_wid_rel} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;
\t\t\t\tINFOPLIST_FILE = Widgets/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = club.apex.lifemaxx.ios.widgets;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{cfg_wat_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tINFOPLIST_FILE = Watch/Info.plist;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = club.apex.lifemaxx.ios.watchkitapp;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "watchos watchsimulator";
\t\t\t\tTARGETED_DEVICE_FAMILY = 4;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{cfg_wat_rel} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tINFOPLIST_FILE = Watch/Info.plist;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = club.apex.lifemaxx.ios.watchkitapp;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "watchos watchsimulator";
\t\t\t\tTARGETED_DEVICE_FAMILY = 4;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{cfg_proj_list} /* Build configuration list for PBXProject "APEX_iOS" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_proj_dbg} /* Debug */,
\t\t\t\t{cfg_proj_rel} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{cfg_main_list} /* Build configuration list for PBXNativeTarget "APEX_iOS" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_main_dbg} /* Debug */,
\t\t\t\t{cfg_main_rel} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{cfg_wid_list} /* Build configuration list for PBXNativeTarget "APEXWidgets" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_wid_dbg} /* Debug */,
\t\t\t\t{cfg_wid_rel} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{cfg_wat_list} /* Build configuration list for PBXNativeTarget "APEXWatch" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_wat_dbg} /* Debug */,
\t\t\t\t{cfg_wat_rel} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {root_obj_id} /* Project object */;
}}
"""

    (xcodeproj / "project.pbxproj").write_text(pbxproj, encoding="utf-8")

    xcscheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{t_main_id}"
               BuildableName = "APEX_iOS.app"
               BlueprintName = "APEX_iOS"
               ReferencedContainer = "container:APEX_iOS.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{t_main_id}"
            BuildableName = "APEX_iOS.app"
            BlueprintName = "APEX_iOS"
            ReferencedContainer = "container:APEX_iOS.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (schemes_dir / "APEX_iOS.xcscheme").write_text(xcscheme, encoding="utf-8")
    print(f"Generated Xcode project cleanly: {xcodeproj}")


if __name__ == "__main__":
    generate()
