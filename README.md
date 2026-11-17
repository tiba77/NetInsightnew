# NetInsight

A PowerShell-based network inventory and security monitoring system for Windows workgroup environments.

## Features
- Automatic network discovery
- Hardware, OS, and security posture collection
- Change detection with SHA-256 hashing
- Security alerts and history tracking
- HTML dashboards and compliance reports
- PsExec-based remote deployment

## Quick Start
1. Configure server path in Client/Config.json
2. Import Server/Modules/Query.psm1
3. Run Update-NIDashboard
4. Deploy clients using Tools/ scripts

## Security
- Never commit credential files
- Rotate shared admin passwords regularly
- Review alerts and history for unauthorized changes

## License
MIT License - see LICENSE file for details.
