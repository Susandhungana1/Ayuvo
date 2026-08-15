/**
 * Band analysis — the one engine behind every status chip and range bar.
 *
 * Colour says urgency (ok / caution / alert), a glyph says direction, and the
 * band name stays as text. The normal band and scale are exported so the range
 * bar and the shaded band behind trend lines are driven from the same source.
 *
 * Thresholds are the product's existing ones (unchanged semantics); only the
 * presentation is unified.
 */

export type StatusLevel = "ok" | "caution" | "alert";

export interface VitalBand {
  level: StatusLevel;
  /** The band name, kept as text: "Elevated", "Stage 1", "Hypothermia", … */
  label: string;
  /** Direction of the band the value moved into. */
  trend?: "up" | "down";
  /** Normal reference band (for RangeBar + shaded trend band). */
  band: { low: number; high: number };
  /** Scale extremes the range bar draws its track over. */
  scale: { min: number; max: number };
}

export const BP_SCALE = { min: 40, max: 240 };
export const BP_BAND = { low: 90, high: 120 };

export const HR_SCALE = { min: 30, max: 200 };
export const HR_BAND = { low: 60, high: 100 };

export const SUGAR_SCALE = { min: 40, max: 400 };
export const SUGAR_BAND = { low: 70, high: 100 };

export const TEMP_SCALE = { min: 30, max: 43 };
export const TEMP_BAND = { low: 36, high: 37.2 };

export const SPO2_SCALE = { min: 60, max: 100 };
export const SPO2_BAND = { low: 95, high: 100 };

/** Blood pressure (systolic + diastolic). */
export function analyzeBP(systolic: number, diastolic: number): VitalBand {
  if (systolic < 90 || diastolic < 60)
    return { level: "alert", label: "Low", trend: "down", band: BP_BAND, scale: BP_SCALE };
  if (systolic <= 120 && diastolic <= 80)
    return { level: "ok", label: "Normal", band: BP_BAND, scale: BP_SCALE };
  if (systolic <= 129 && diastolic <= 80)
    return { level: "caution", label: "Elevated", trend: "up", band: BP_BAND, scale: BP_SCALE };
  if (systolic <= 139 || diastolic <= 89)
    return { level: "caution", label: "Stage 1", trend: "up", band: BP_BAND, scale: BP_SCALE };
  if (systolic <= 179 || diastolic <= 119)
    return { level: "alert", label: "Stage 2", trend: "up", band: BP_BAND, scale: BP_SCALE };
  return { level: "alert", label: "Crisis", trend: "up", band: BP_BAND, scale: BP_SCALE };
}

/** Heart rate (bpm). */
export function analyzeHR(hr: number): VitalBand {
  if (hr < 60)
    return { level: "caution", label: "Low", trend: "down", band: HR_BAND, scale: HR_SCALE };
  if (hr <= 100)
    return { level: "ok", label: "Normal", band: HR_BAND, scale: HR_SCALE };
  if (hr <= 120)
    return { level: "caution", label: "Elevated", trend: "up", band: HR_BAND, scale: HR_SCALE };
  return { level: "alert", label: "High", trend: "up", band: HR_BAND, scale: HR_SCALE };
}

/** Blood sugar (mg/dL). */
export function analyzeSugar(glucose: number): VitalBand {
  if (glucose < 70)
    return { level: "alert", label: "Low", trend: "down", band: SUGAR_BAND, scale: SUGAR_SCALE };
  if (glucose <= 100)
    return { level: "ok", label: "Normal", band: SUGAR_BAND, scale: SUGAR_SCALE };
  if (glucose <= 125)
    return { level: "caution", label: "Prediabetic", trend: "up", band: SUGAR_BAND, scale: SUGAR_SCALE };
  if (glucose <= 180)
    return { level: "alert", label: "High", trend: "up", band: SUGAR_BAND, scale: SUGAR_SCALE };
  return { level: "alert", label: "Very High", trend: "up", band: SUGAR_BAND, scale: SUGAR_SCALE };
}

/** Body temperature (°C). */
export function analyzeTemp(temp: number): VitalBand {
  if (temp < 35)
    return { level: "alert", label: "Hypothermia", trend: "down", band: TEMP_BAND, scale: TEMP_SCALE };
  if (temp < 36)
    return { level: "caution", label: "Low", trend: "down", band: TEMP_BAND, scale: TEMP_SCALE };
  if (temp <= 37.2)
    return { level: "ok", label: "Normal", band: TEMP_BAND, scale: TEMP_SCALE };
  if (temp <= 38)
    return { level: "caution", label: "Mild Fever", trend: "up", band: TEMP_BAND, scale: TEMP_SCALE };
  if (temp <= 39)
    return { level: "alert", label: "Fever", trend: "up", band: TEMP_BAND, scale: TEMP_SCALE };
  return { level: "alert", label: "High Fever", trend: "up", band: TEMP_BAND, scale: TEMP_SCALE };
}

/** Oxygen saturation (%). */
export function analyzeSpO2(oxygen: number): VitalBand {
  if (oxygen >= 95)
    return { level: "ok", label: "Normal", band: SPO2_BAND, scale: SPO2_SCALE };
  if (oxygen >= 90)
    return { level: "caution", label: "Mild Low", trend: "down", band: SPO2_BAND, scale: SPO2_SCALE };
  if (oxygen >= 80)
    return { level: "alert", label: "Low", trend: "down", band: SPO2_BAND, scale: SPO2_SCALE };
  return { level: "alert", label: "Critical", trend: "down", band: SPO2_BAND, scale: SPO2_SCALE };
}