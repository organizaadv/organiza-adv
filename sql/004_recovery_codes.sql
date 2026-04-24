-- Tabela para códigos OTP de recuperação de senha
CREATE TABLE IF NOT EXISTS recovery_codes (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  email       text        NOT NULL,
  code        text        NOT NULL,
  hashed_token text,
  expires_at  timestamptz NOT NULL,
  used        boolean     DEFAULT false,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE recovery_codes ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_recovery_codes_email   ON recovery_codes(email);
CREATE INDEX IF NOT EXISTS idx_recovery_codes_expires ON recovery_codes(expires_at);
