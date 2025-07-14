# Changelog

All notable changes to the SPIRE Helm chart will be documented in this file.

## [1.1.0] - 2025-07-14

### Updated
- **SPIRE Version**: Upgraded from 1.6.3 to 1.12.4 (latest stable)
- **PostgreSQL Version**: Updated dependency from 12.x.x to 15.x.x
- **Storage Allocation**: Increased default SPIRE server storage from 1Gi to 5Gi
- **Production Storage**: Increased production PostgreSQL storage from 20Gi to 100Gi

### Added
- **Cache Configuration**: Added x509_svid_cache_max_size configuration for improved performance
- **Enhanced Production Values**: Added cache tuning for production environments
- **Container Runtime Support**: Updated documentation to include Rancher Desktop support
- **Kubernetes Version**: Updated minimum supported version to 1.24+

### Fixed
- **Workload Service Images**: Updated user-service from nginx:1.21 to alpine/curl:latest for consistency
- **Configuration Templates**: Added cache configuration sections to server and agent templates

### Security
- **Version Security**: Addresses multiple security advisories from SPIRE versions 1.6.3 to 1.12.4
- **Performance Improvements**: Enhanced memory usage and caching capabilities

### Breaking Changes
- **Minimum Kubernetes Version**: Now requires Kubernetes 1.24+
- **Cache Configuration**: LRU cache is now unconditionally enabled (SPIRE 1.12.x behavior)

### Migration Notes
- Review your configuration for any deprecated features before upgrading
- The k8s_sat NodeAttestor plugin has been removed in SPIRE 1.12.0
- Consider tuning `x509_svid_cache_max_size` based on your workload requirements

## [1.0.0] - 2025-07-13

### Added
- Initial SPIRE Helm chart release
- SPIRE Server and Agent deployment templates
- PostgreSQL database integration
- RBAC configuration templates
- Example workload services
- Production and development value overrides
- Comprehensive documentation