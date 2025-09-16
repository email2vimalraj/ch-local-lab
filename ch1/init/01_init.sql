-- Create roles
CREATE ROLE IF NOT EXISTS np_user_role ON CLUSTER ch_np_cluster;
CREATE ROLE IF NOT EXISTS np_power_role ON CLUSTER ch_np_cluster;
CREATE ROLE IF NOT EXISTS np_admin_role ON CLUSTER ch_np_cluster;
CREATE ROLE IF NOT EXISTS np_admin_read_role ON CLUSTER ch_np_cluster;
CREATE ROLE IF NOT EXISTS np_dba_read_role ON CLUSTER ch_np_cluster;

-- Grant for user role
GRANT SELECT ON default.log_app_distributed TO np_user_role ON CLUSTER ch_np_cluster;
GRANT SELECT ON default.log_app TO np_user_role ON CLUSTER ch_np_cluster;
GRANT SELECT ON default.log_app_ingestion_stats TO np_user_role ON CLUSTER ch_np_cluster;
GRANT SELECT ON default.log_k8_events TO np_user_role ON CLUSTER ch_np_cluster;
GRANT SELECT ON default.log_k8_events_distributed TO np_user_role ON CLUSTER ch_np_cluster;
GRANT SELECT ON lookups.* TO np_user_role ON CLUSTER ch_np_cluster;

-- Grant for admin role
GRANT ALL ON *.* TO np_admin_role ON CLUSTER ch_np_cluster;

-- Grant for admin read role
GRANT SELECT ON *.* TO np_admin_read_role ON CLUSTER ch_np_cluster;

-- Grant for power role
GRANT ALL ON lookups.* TO np_power_role ON CLUSTER ch_np_cluster;

-- Create local users
CREATE USER IF NOT EXISTS np_user ON CLUSTER ch_np_cluster IDENTIFIED WITH sha256_password BY 'np_user_password';
CREATE USER IF NOT EXISTS np_power ON CLUSTER ch_np_cluster IDENTIFIED WITH sha256_password BY 'np_power_password';
CREATE USER IF NOT EXISTS np_admin ON CLUSTER ch_np_cluster IDENTIFIED WITH sha256_password BY 'np_admin_password';
CREATE USER IF NOT EXISTS np_admin_read ON CLUSTER ch_np_cluster IDENTIFIED WITH sha256_password BY 'np_admin_read_password';

-- Grant admin role to admin user
GRANT np_admin_role TO np_admin ON CLUSTER ch_np_cluster;

-- Grant admin read role to admin read user
GRANT np_admin_read_role TO np_admin_read ON CLUSTER ch_np_cluster;

-- Grant power role to power user
GRANT np_power_role TO np_power ON CLUSTER ch_np_cluster;

-- Grant user role to user
GRANT np_user_role TO np_user ON CLUSTER ch_np_cluster;
