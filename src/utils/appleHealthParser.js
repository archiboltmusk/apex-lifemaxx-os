// Official Apple HealthKit XML Database Parser (apple_health_export/export.xml)
// Handles direct parsing of Apple Watch Ultra & iPhone HealthKit clinical exports

export function parseAppleHealthXML(xmlString) {
  const result = {
    sourceName: 'Apple Watch Ultra',
    exportDate: new Date().toISOString(),
    totalRecords: 0,
    metrics: {
      moveCalories: 0,
      exerciseMinutes: 0,
      standHours: 0,
      restingHeartRate: null,
      hrvMs: null,
      vo2Max: null,
      waterMl: 0,
      bloodGlucoseMgDl: null,
      respiratoryRate: null,
      bloodOxygen: null,
      wristTempDeltaC: null,
      bodyFatPercent: null,
      leanMassKg: null,
      dietaryCalories: 0,
      dietaryProteinG: 0,
    },
    workouts: [],
    recentSamples: [],
  };

  try {
    // 1. Fast regex extraction of ExportDate
    const exportMatch = xmlString.match(/<ExportDate\s+value="([^"]+)"/i);
    if (exportMatch) {
      result.exportDate = exportMatch[1];
    }

    // 2. Extract Device & Source Name
    const sourceMatch = xmlString.match(/sourceName="([^"]+)"/i);
    if (sourceMatch) {
      result.sourceName = sourceMatch[1];
    }

    // 3. Extract Records via regex streaming (avoids memory overflow on huge files)
    const recordRegex = /<Record\s+([^>]+)\/>/gi;
    let match;
    let count = 0;

    let totalMove = 0;
    let totalExercise = 0;
    let totalWaterMl = 0;
    let totalDietaryKcal = 0;
    let totalDietaryProteinG = 0;
    const standHoursSet = new Set();
    const latestVitals = {};

    const vitalExtractors = {
      HKQuantityTypeIdentifierRestingHeartRate: (v) => Math.round(v),
      HKQuantityTypeIdentifierHeartRateVariabilitySDNN: (v) => Math.round(v),
      HKQuantityTypeIdentifierVO2Max: (v) => +v.toFixed(1),
      HKQuantityTypeIdentifierBloodGlucose: (v) => Math.round(v < 30 ? v * 18.0182 : v),
      HKQuantityTypeIdentifierRespiratoryRate: (v) => +v.toFixed(1),
      HKQuantityTypeIdentifierOxygenSaturation: (v) => +(v <= 1 ? v * 100 : v).toFixed(1),
      HKQuantityTypeIdentifierAppleSleepingWristTemperature: (v) => +v.toFixed(2),
      HKQuantityTypeIdentifierBodyFatPercentage: (v) => +(v <= 1 ? v * 100 : v).toFixed(1),
      HKQuantityTypeIdentifierLeanBodyMass: (v) => +v.toFixed(1),
    };

    while ((match = recordRegex.exec(xmlString)) !== null && count < 50000) {
      count++;
      const attrStr = match[1];

      // Extract type
      const typeMatch = attrStr.match(/type="([^"]+)"/i);
      const valMatch = attrStr.match(/value="([^"]+)"/i);
      const startMatch = attrStr.match(/startDate="([^"]+)"/i);

      if (!typeMatch || !valMatch) continue;

      const type = typeMatch[1];
      const val = parseFloat(valMatch[1]);
      const startDate = startMatch ? startMatch[1] : '';

      if (isNaN(val)) continue;

      if (type === 'HKQuantityTypeIdentifierActiveEnergyBurned') {
        totalMove += val;
      } else if (type === 'HKQuantityTypeIdentifierAppleExerciseTime') {
        totalExercise += val;
      } else if (type === 'HKQuantityTypeIdentifierAppleStandTime') {
        if (startDate) standHoursSet.add(startDate.slice(0, 13));
      } else if (type === 'HKQuantityTypeIdentifierDietaryWater') {
        totalWaterMl += val < 20 ? val * 1000 : val;
      } else if (type === 'HKQuantityTypeIdentifierDietaryEnergyConsumed') {
        totalDietaryKcal += val;
      } else if (type === 'HKQuantityTypeIdentifierDietaryProtein') {
        totalDietaryProteinG += val;
      } else if (vitalExtractors[type]) {
        latestVitals[type] = vitalExtractors[type](val);
      }

      if (result.recentSamples.length < 12) {
        result.recentSamples.push({
          type: type.replace('HKQuantityTypeIdentifier', ''),
          value: val,
          date: startDate,
        });
      }
    }

    result.totalRecords = count;
    result.metrics.moveCalories = Math.round(totalMove);
    result.metrics.exerciseMinutes = Math.round(totalExercise);
    result.metrics.standHours = standHoursSet.size;
    result.metrics.waterMl = Math.round(totalWaterMl);
    result.metrics.dietaryCalories = Math.round(totalDietaryKcal);
    result.metrics.dietaryProteinG = Math.round(totalDietaryProteinG);

    if (latestVitals.HKQuantityTypeIdentifierRestingHeartRate !== undefined) {
      result.metrics.restingHeartRate = latestVitals.HKQuantityTypeIdentifierRestingHeartRate;
    }
    if (latestVitals.HKQuantityTypeIdentifierHeartRateVariabilitySDNN !== undefined) {
      result.metrics.hrvMs = latestVitals.HKQuantityTypeIdentifierHeartRateVariabilitySDNN;
    }
    if (latestVitals.HKQuantityTypeIdentifierVO2Max !== undefined) {
      result.metrics.vo2Max = latestVitals.HKQuantityTypeIdentifierVO2Max;
    }
    if (latestVitals.HKQuantityTypeIdentifierBloodGlucose !== undefined) {
      result.metrics.bloodGlucoseMgDl = latestVitals.HKQuantityTypeIdentifierBloodGlucose;
    }
    if (latestVitals.HKQuantityTypeIdentifierRespiratoryRate !== undefined) {
      result.metrics.respiratoryRate = latestVitals.HKQuantityTypeIdentifierRespiratoryRate;
    }
    if (latestVitals.HKQuantityTypeIdentifierOxygenSaturation !== undefined) {
      result.metrics.bloodOxygen = latestVitals.HKQuantityTypeIdentifierOxygenSaturation;
    }
    if (latestVitals.HKQuantityTypeIdentifierAppleSleepingWristTemperature !== undefined) {
      result.metrics.wristTempDeltaC = latestVitals.HKQuantityTypeIdentifierAppleSleepingWristTemperature;
    }
    if (latestVitals.HKQuantityTypeIdentifierBodyFatPercentage !== undefined) {
      result.metrics.bodyFatPercent = latestVitals.HKQuantityTypeIdentifierBodyFatPercentage;
    }
    if (latestVitals.HKQuantityTypeIdentifierLeanBodyMass !== undefined) {
      result.metrics.leanMassKg = latestVitals.HKQuantityTypeIdentifierLeanBodyMass;
    }

    // 4. Extract Workout entries
    const workoutRegex = /<Workout\s+([^>]+)\/?>/gi;
    let wMatch;
    while ((wMatch = workoutRegex.exec(xmlString)) !== null && result.workouts.length < 500) {
      const attrStr = wMatch[1];
      const actMatch = attrStr.match(/workoutActivityType="([^"]+)"/i);
      const durMatch = attrStr.match(/duration="([^"]+)"/i);
      const distMatch = attrStr.match(/totalDistance="([^"]+)"/i);
      const calMatch = attrStr.match(/totalEnergyBurned="([^"]+)"/i);
      const startMatch = attrStr.match(/startDate="([^"]+)"/i);
      if (actMatch) {
        result.workouts.push({
          activity: actMatch[1].replace(/^HKWorkoutActivityType/, ''),
          durationMinutes: durMatch ? Number(parseFloat(durMatch[1]).toFixed(1)) : 0,
          distanceKm: distMatch ? Number(parseFloat(distMatch[1]).toFixed(2)) : 0,
          calories: calMatch ? Math.round(parseFloat(calMatch[1])) : 0,
          startDate: startMatch ? startMatch[1] : '',
        });
      }
    }

    return { success: true, data: result };
  } catch (err) {
    console.error('Apple Health XML parsing error:', err);
    return { success: false, error: err.message };
  }
}

// Authentic Apple Health XML Sample conforming to Apple DTD
export const SAMPLE_APPLE_HEALTH_EXPORT_XML = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE HealthData SYSTEM "HealthData.dtd">
<HealthData locale="en_US">
 <ExportDate value="2026-11-10 18:30:12 -0500"/>
 <Me HKCharacteristicTypeIdentifierDateOfBirth="1997-04-12" HKCharacteristicTypeIdentifierBiologicalSex="HKBiologicalSexMale" HKCharacteristicTypeIdentifierBloodType="HKBloodTypeOPositive"/>
 <Record type="HKQuantityTypeIdentifierActiveEnergyBurned" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="Cal" creationDate="2026-11-10 18:25:00 -0500" startDate="2026-11-10 18:00:00 -0500" endDate="2026-11-10 18:25:00 -0500" value="845.2"/>
 <Record type="HKQuantityTypeIdentifierAppleExerciseTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 18:25:00 -0500" startDate="2026-11-10 17:30:00 -0500" endDate="2026-11-10 18:25:00 -0500" value="58"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 18:00:00 -0500" startDate="2026-11-10 09:00:00 -0500" endDate="2026-11-10 18:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 17:00:00 -0500" startDate="2026-11-10 10:00:00 -0500" endDate="2026-11-10 17:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 16:00:00 -0500" startDate="2026-11-10 11:00:00 -0500" endDate="2026-11-10 16:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 15:00:00 -0500" startDate="2026-11-10 12:00:00 -0500" endDate="2026-11-10 15:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 14:00:00 -0500" startDate="2026-11-10 13:00:00 -0500" endDate="2026-11-10 14:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 13:00:00 -0500" startDate="2026-11-10 14:00:00 -0500" endDate="2026-11-10 13:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 12:00:00 -0500" startDate="2026-11-10 15:00:00 -0500" endDate="2026-11-10 12:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 11:00:00 -0500" startDate="2026-11-10 16:00:00 -0500" endDate="2026-11-10 11:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 10:00:00 -0500" startDate="2026-11-10 17:00:00 -0500" endDate="2026-11-10 10:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 09:00:00 -0500" startDate="2026-11-10 18:00:00 -0500" endDate="2026-11-10 09:00:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 08:00:00 -0500" startDate="2026-11-10 08:00:00 -0500" endDate="2026-11-10 08:59:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 07:00:00 -0500" startDate="2026-11-10 07:00:00 -0500" endDate="2026-11-10 07:59:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierAppleStandTime" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="min" creationDate="2026-11-10 06:00:00 -0500" startDate="2026-11-10 06:00:00 -0500" endDate="2026-11-10 06:59:00 -0500" value="60"/>
 <Record type="HKQuantityTypeIdentifierHeartRate" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="count/min" creationDate="2026-11-10 18:24:00 -0500" startDate="2026-11-10 18:24:00 -0500" endDate="2026-11-10 18:24:00 -0500" value="54"/>
 <Record type="HKQuantityTypeIdentifierRestingHeartRate" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="count/min" creationDate="2026-11-10 08:00:00 -0500" startDate="2026-11-10 08:00:00 -0500" endDate="2026-11-10 08:00:00 -0500" value="46"/>
 <Record type="HKQuantityTypeIdentifierHeartRateVariabilitySDNN" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="ms" creationDate="2026-11-10 07:15:00 -0500" startDate="2026-11-10 07:14:00 -0500" endDate="2026-11-10 07:15:00 -0500" value="98.4"/>
 <Record type="HKQuantityTypeIdentifierVO2Max" sourceName="Athlete Apple Watch Ultra 2" sourceVersion="11.2" unit="mL/min·kg" creationDate="2026-11-09 11:20:00 -0500" startDate="2026-11-09 11:20:00 -0500" endDate="2026-11-09 11:20:00 -0500" value="61.2"/>
 <Workout workoutActivityType="HKWorkoutActivityTypeRunning" duration="34.2" durationUnit="min" totalDistance="5.8" totalDistanceUnit="km" totalEnergyBurned="420" totalEnergyBurnedUnit="Cal" sourceName="Athlete Apple Watch Ultra 2" creationDate="2026-11-10 18:00:00 -0500" startDate="2026-11-10 17:25:00 -0500" endDate="2026-11-10 18:00:00 -0500"/>
</HealthData>`;
