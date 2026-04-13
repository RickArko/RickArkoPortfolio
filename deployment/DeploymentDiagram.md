# AWS App Runner Deployment Architecture

## Current flow

```text
Git repo -> Docker build -> Amazon ECR -> AWS App Runner -> rickarko.com
                                                  |
                                                  -> Route 53
```

## Primary resources

### ECR

- stores the application image
- created and updated via `deployment/bin/ecr-setup.sh`

### App Runner

- runs the containerized Flask application
- serves the public App Runner URL
- handles autoscaling and TLS for the associated custom domain

### Route 53

- hosts the DNS zone
- stores the apex alias, `www` CNAME, and validation CNAME records
- updated via `deployment/bin/apprunner-domain-setup.sh`

## Linux-first command surface

```bash
make ecr-setup
make domain-setup
make domain-status
make domain-debug
```

## Script layout

```text
deployment/
├── bin/
│   ├── common.sh
│   ├── ecr-setup.sh
│   ├── apprunner-domain-setup.sh
│   ├── apprunner-domain-status.sh
│   └── apprunner-debug.sh
└── windows/
    └── legacy/
        └── *.ps1
```
