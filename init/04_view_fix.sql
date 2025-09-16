
-- Ensure distributed alias exists locally
CREATE OR REPLACE VIEW IF NOT EXISTS default.log_app_distributed AS
SELECT * FROM default.log_app;
