import { z } from 'zod';

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(8080),
  IDENTITY_PORT: z.coerce.number().int().positive().default(8081),
  DATABASE_URL: z.string().min(1),
  MEDQUR_OIDC_ISSUER: z.string().url().optional().or(z.literal('')),
  MEDQUR_OIDC_AUDIENCE: z.string().optional().default('medqur-api'),
  MEDQUR_OIDC_JWKS_URL: z.string().url().optional().or(z.literal('')),
  MEDQUR_DEV_AUTH: z.enum(['true', 'false']).default('false'),
  MEDQUR_ALLOWED_ORIGINS: z.string().optional().default(''),
  MEDQUR_CATALOG_SIGNING_PRIVATE_KEY_PEM: z.string().optional().default(''),
  MEDQUR_CATALOG_SIGNING_KEY_ID: z.string().default('medqur-catalog-v1'),
  MEDQUR_STAFF_BADGE_SIGNING_PRIVATE_KEY_PEM: z.string().optional().default(''),
  MEDQUR_STAFF_BADGE_VERIFY_PUBLIC_KEY_PEM: z.string().optional().default(''),
  MEDQUR_STAFF_BADGE_KEY_ID: z.string().default('medqur-staff-badge-v1'),
  MEDQUR_STAFF_BADGE_VALID_DAYS: z.coerce.number().int().min(1).max(1095).default(730),
  MEDQUR_FHIR_BASE_URL: z.string().url().optional().or(z.literal('')),
});

const parsed = envSchema.parse(process.env);

export const config = {
  port: parsed.PORT,
  identityPort: parsed.IDENTITY_PORT,
  databaseUrl: parsed.DATABASE_URL,
  oidcIssuer: parsed.MEDQUR_OIDC_ISSUER || null,
  oidcAudience: parsed.MEDQUR_OIDC_AUDIENCE,
  oidcJwksUrl: parsed.MEDQUR_OIDC_JWKS_URL || null,
  devAuth: parsed.MEDQUR_DEV_AUTH === 'true',
  allowedOrigins: parsed.MEDQUR_ALLOWED_ORIGINS
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean),
  catalogSigningPrivateKeyPem: parsed.MEDQUR_CATALOG_SIGNING_PRIVATE_KEY_PEM,
  catalogSigningKeyId: parsed.MEDQUR_CATALOG_SIGNING_KEY_ID,
  staffBadgeSigningPrivateKeyPem: parsed.MEDQUR_STAFF_BADGE_SIGNING_PRIVATE_KEY_PEM,
  staffBadgeVerifyPublicKeyPem: parsed.MEDQUR_STAFF_BADGE_VERIFY_PUBLIC_KEY_PEM,
  staffBadgeKeyId: parsed.MEDQUR_STAFF_BADGE_KEY_ID,
  staffBadgeDefaultValidDays: parsed.MEDQUR_STAFF_BADGE_VALID_DAYS,
  fhirBaseUrl: parsed.MEDQUR_FHIR_BASE_URL || null,
} as const;
