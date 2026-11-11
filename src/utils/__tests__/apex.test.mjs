import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseAppleHealthXML,
  SAMPLE_APPLE_HEALTH_EXPORT_XML,
} from '../appleHealthParser.js';

test('parseAppleHealthXML returns null vitals on empty export (zero fake data)', () => {
  const res = parseAppleHealthXML('<HealthData locale="en_US"></HealthData>');
  assert.equal(res.success, true);
  assert.equal(res.data.totalRecords, 0);
  assert.equal(res.data.metrics.moveCalories, 0);
  assert.equal(res.data.metrics.restingHeartRate, null);
  assert.equal(res.data.metrics.hrvMs, null);
  assert.equal(res.data.metrics.vo2Max, null);
  assert.equal(res.data.metrics.bloodGlucoseMgDl, null);
  assert.equal(res.data.workouts.length, 0);
});

test('parseAppleHealthXML extracts authentic Apple Watch Ultra sample XML accurately', () => {
  const res = parseAppleHealthXML(SAMPLE_APPLE_HEALTH_EXPORT_XML);
  assert.equal(res.success, true);
  assert.equal(res.data.sourceName, 'Athlete Apple Watch Ultra 2');
  assert.equal(res.data.metrics.moveCalories, 845);
  assert.equal(res.data.metrics.exerciseMinutes, 58);
  assert.equal(res.data.metrics.restingHeartRate, 46);
  assert.equal(res.data.metrics.hrvMs, 98);
  assert.equal(res.data.metrics.vo2Max, 61.2);
  assert.ok(res.data.metrics.standHours >= 10);
  assert.equal(res.data.workouts.length, 1);
  assert.equal(res.data.workouts[0].activity, 'Running');
});

test('parseAppleHealthXML normalizes mmol/L glucose and fractional SpO2', () => {
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
  <HealthData>
    <Record type="HKQuantityTypeIdentifierBloodGlucose" value="5.5" startDate="2026-11-11 08:00:00 +0000"/>
    <Record type="HKQuantityTypeIdentifierOxygenSaturation" value="0.98" startDate="2026-11-11 07:00:00 +0000"/>
    <Record type="HKQuantityTypeIdentifierBodyFatPercentage" value="0.145" startDate="2026-11-11 07:00:00 +0000"/>
  </HealthData>`;
  const res = parseAppleHealthXML(xml);
  assert.equal(res.success, true);
  assert.equal(res.data.metrics.bloodGlucoseMgDl, 99);
  assert.equal(res.data.metrics.bloodOxygen, 98);
  assert.equal(res.data.metrics.bodyFatPercent, 14.5);
});
