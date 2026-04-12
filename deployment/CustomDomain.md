# Custom Domain Setup

Target mapping:

- `rickarko.com` -> App Runner apex alias
- `www.rickarko.com` -> App Runner CNAME

## Current Route 53 details

- **Hosted zone ID:** `Z08302203OZOEJNRETXLE`
- **App Runner alias zone ID:** `Z01915732ZBZKC8D32TPT`

## Standard workflow

```bash
make domain-setup
make domain-status
```

That flow uses:

- `deployment/bin/apprunner-domain-setup.sh`
- `deployment/bin/apprunner-domain-status.sh`

## Direct usage

```bash
./deployment/bin/apprunner-domain-setup.sh \
  --domain rickarko.com \
  --service-name RickArko_Portfolio \
  --region us-east-1

./deployment/bin/apprunner-domain-status.sh --detailed
./deployment/bin/apprunner-debug.sh --watch
```

## Re-associate a broken domain

```bash
aws apprunner disassociate-custom-domain \
  --service-arn "$APPRUNNER_SERVICE_ARN" \
  --domain-name rickarko.com

sleep 15

make domain-setup
```

## Quick verification

```bash
nslookup rickarko.com
nslookup www.rickarko.com
curl -I https://rickarko.com
curl -I https://www.rickarko.com
```
