import { z } from 'zod';

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(8080),
  DATABASE_URL: z.string().min(1),
  MEDQUR_OIDC_ISSUER: z.string().url().optional().or(z.literal('')),
  MEDQUR_OIDC_AUDIENCE: z.string().optional().default('medqur-api'),
  MEDQUR_OIDC_JWKS_URL: z.string().url().optional().or(z.literal('')),
  MEDQUR_DEV_AUTH: z.enum(['true', 'false']).default('false'),
  MEDQUR_CATALOG_SIGNING_PRIVATE_KEY_PEM: z.string().optional().default(''),
  MEDQUR_CATALOG_SIGNING_KEY_ID: z.string().default('medqur-catalog-v1'),
  MEDQUR_FHIR_BASE_URL: z.string().url().optional().or(z.literal('')),
});

const parsed = envSchema.parse(process.env);

export const config = {
  port: parsed.PORT,
  databaseUrl: parsed.DATABASE_URL,
  oidcIssuer: parsed.MEDQUR_OIDC_ISSUER || null,
  oidcAudience: parsed.MEDQUR_OIDC_AUDIENCE,
  oidcJwksUrl: parsed.MEDQUR_OIDC_JWKS_URL || null,
  devAuth: parsed.MEDQUR_DEV_AUTH === 'true',
  catalogSigningPrivateKeyPem: parsed.MEDQUR_CATALOG_SIGNING_PRIVATE_KEY_PEM,
  catalogSigningKeyId: parsed.MEDQUR_CATALOG_SIGNING_KEY_ID,
  fhirBaseUrl: parsed.MEDQUR_FHIR_BASE_URL || null,
} as const;
