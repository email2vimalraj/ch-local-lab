-- Create roles
CREATE ROLE IF NOT EXISTS np_user_role;
CREATE ROLE IF NOT EXISTS np_power_role;
CREATE ROLE IF NOT EXISTS np_admin_role;
CREATE ROLE IF NOT EXISTS np_admin_read_role;
CREATE ROLE IF NOT EXISTS np_dba_read_role;

-- Grant for user role
GRANT SELECT ON default.log_app_distributed TO np_user_role;
GRANT SELECT ON default.log_app TO np_user_role;
GRANT SELECT ON default.log_app_ingestion_stats TO np_user_role;
GRANT SELECT ON default.log_k8_events TO np_user_role;
GRANT SELECT ON default.log_k8_events_distributed TO np_user_role;
GRANT SELECT ON lookups.* TO np_user_role;

-- Grant for admin role
GRANT ALL ON *.* TO np_admin_role;

-- Grant for admin read role
GRANT SELECT ON *.* TO np_admin_read_role;

-- Grant for power role
GRANT ALL ON lookups.* TO np_power_role;

-- Create local users
CREATE USER IF NOT EXISTS np_user IDENTIFIED WITH sha256_password BY 'np_user_password';
CREATE USER IF NOT EXISTS np_power IDENTIFIED WITH sha256_password BY 'np_power_password';
CREATE USER IF NOT EXISTS np_admin IDENTIFIED WITH sha256_password BY 'np_admin_password';
CREATE USER IF NOT EXISTS np_admin_read IDENTIFIED WITH sha256_password BY 'np_admin_read_password';

-- Grant admin role to admin user
GRANT np_admin_role TO np_admin;

-- Grant admin read role to admin read user
GRANT np_admin_read_role TO np_admin_read;

-- Grant power role to power user
GRANT np_power_role TO np_power;

-- Grant user role to user
GRANT np_user_role TO np_user;
