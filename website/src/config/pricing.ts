/**
 * Pricing configuration — single source of truth.
 *
 * Used by: landing page, terms page, anywhere pricing is displayed.
 * Mirrors the iOS app's SubscriptionConfig.regionPricing.
 *
 * All amounts are in USD. The App Store handles local-currency conversion
 * at checkout; these values are for display purposes on the website.
 */

export type PricingTier = 'standard' | 'reduced' | 'premium'

export interface TierPricing {
  yearly: number
  yearlyDisplay: string
  monthlyEquivalent: string
  trialDays: number
  productId: string
  tier: PricingTier
}

const TIERS: Record<PricingTier, TierPricing> = {
  standard: {
    yearly: 29.99,
    yearlyDisplay: '$29.99',
    monthlyEquivalent: '$2.49',
    trialDays: 7,
    productId: 'com.lasohealth.yearly',
    tier: 'standard',
  },
  reduced: {
    yearly: 14.99,
    yearlyDisplay: '$14.99',
    monthlyEquivalent: '$1.24',
    trialDays: 7,
    productId: 'com.lasohealth.yearly',
    tier: 'reduced',
  },
  premium: {
    yearly: 34.99,
    yearlyDisplay: '$34.99',
    monthlyEquivalent: '$2.91',
    trialDays: 7,
    productId: 'com.lasohealth.yearly',
    tier: 'premium',
  },
}

const COUNTRY_TIERS: Record<string, PricingTier> = {
  US: 'standard', CA: 'standard', GB: 'standard', DE: 'standard',
  FR: 'standard', AU: 'standard', JP: 'standard', KR: 'standard',
  IT: 'standard', ES: 'standard', NL: 'standard', AT: 'standard',
  BE: 'standard', FI: 'standard', IE: 'standard', PT: 'standard',
  NZ: 'standard', TW: 'standard', HK: 'standard', IL: 'standard',
  AE: 'standard', SA: 'standard', QA: 'standard', KW: 'standard',

  IN: 'reduced', BR: 'reduced', MX: 'reduced', TR: 'reduced',
  ID: 'reduced', PH: 'reduced', TH: 'reduced', VN: 'reduced',
  PK: 'reduced', NG: 'reduced', EG: 'reduced', ZA: 'reduced',
  AR: 'reduced', CL: 'reduced', CO: 'reduced', PE: 'reduced',
  BD: 'reduced', LK: 'reduced', KE: 'reduced', GH: 'reduced',
  UA: 'reduced', RO: 'reduced', BG: 'reduced', MY: 'reduced',

  CH: 'premium', NO: 'premium', DK: 'premium', SE: 'premium',
  SG: 'premium', LU: 'premium',
}

const TIMEZONE_COUNTRIES: Record<string, string> = {
  'Asia/Kolkata': 'IN', 'Asia/Calcutta': 'IN',
  'America/Sao_Paulo': 'BR', 'America/Fortaleza': 'BR', 'America/Recife': 'BR',
  'America/Mexico_City': 'MX', 'America/Cancun': 'MX', 'America/Monterrey': 'MX',
  'Europe/Istanbul': 'TR',
  'Asia/Jakarta': 'ID', 'Asia/Makassar': 'ID', 'Asia/Jayapura': 'ID',
  'Asia/Manila': 'PH', 'Asia/Bangkok': 'TH',
  'Asia/Ho_Chi_Minh': 'VN', 'Asia/Saigon': 'VN',
  'Asia/Karachi': 'PK', 'Africa/Lagos': 'NG', 'Africa/Cairo': 'EG',
  'Africa/Johannesburg': 'ZA',
  'America/Argentina/Buenos_Aires': 'AR', 'America/Buenos_Aires': 'AR',
  'America/Santiago': 'CL', 'America/Bogota': 'CO', 'America/Lima': 'PE',
  'Asia/Dhaka': 'BD', 'Asia/Colombo': 'LK',
  'Africa/Nairobi': 'KE', 'Africa/Accra': 'GH',
  'Europe/Kyiv': 'UA', 'Europe/Kiev': 'UA',
  'Europe/Bucharest': 'RO', 'Europe/Sofia': 'BG', 'Asia/Kuala_Lumpur': 'MY',
  'Europe/Zurich': 'CH', 'Europe/Oslo': 'NO', 'Europe/Copenhagen': 'DK',
  'Europe/Stockholm': 'SE', 'Asia/Singapore': 'SG', 'Europe/Luxembourg': 'LU',
  'America/New_York': 'US', 'America/Chicago': 'US', 'America/Denver': 'US',
  'America/Los_Angeles': 'US', 'America/Phoenix': 'US', 'America/Anchorage': 'US',
  'Pacific/Honolulu': 'US',
  'America/Toronto': 'CA', 'America/Vancouver': 'CA', 'America/Edmonton': 'CA',
  'Europe/London': 'GB', 'Europe/Berlin': 'DE', 'Europe/Paris': 'FR',
  'Australia/Sydney': 'AU', 'Australia/Melbourne': 'AU', 'Australia/Perth': 'AU',
  'Asia/Tokyo': 'JP', 'Asia/Seoul': 'KR',
  'Europe/Rome': 'IT', 'Europe/Madrid': 'ES', 'Europe/Amsterdam': 'NL',
  'Europe/Vienna': 'AT', 'Europe/Brussels': 'BE', 'Europe/Helsinki': 'FI',
  'Europe/Dublin': 'IE', 'Europe/Lisbon': 'PT',
  'Pacific/Auckland': 'NZ', 'Asia/Taipei': 'TW', 'Asia/Hong_Kong': 'HK',
  'Asia/Jerusalem': 'IL', 'Asia/Dubai': 'AE', 'Asia/Riyadh': 'SA',
  'Asia/Qatar': 'QA', 'Asia/Kuwait': 'KW',
}

export function detectCountry(): string | null {
  if (typeof navigator === 'undefined') return null
  // Timezone is the most reliable signal for physical location
  try {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
    const country = TIMEZONE_COUNTRIES[tz]
    if (country) return country
  } catch { /* ignore */ }
  // Fall back to browser locale region
  try {
    for (const lang of navigator.languages) {
      if (lang.includes('-')) {
        const locale = new Intl.Locale(lang)
        if (locale.region) return locale.region.toUpperCase()
      }
    }
  } catch { /* ignore */ }
  return null
}

export function getTierForCountry(countryCode: string | null): PricingTier {
  if (!countryCode) return 'standard'
  return COUNTRY_TIERS[countryCode.toUpperCase()] ?? 'standard'
}

export function getPricing(countryCode: string | null): TierPricing {
  return TIERS[getTierForCountry(countryCode)]
}

export function getDefaultPricing(): TierPricing {
  return TIERS.standard
}
