#!/usr/bin/env bash
set -e

echo "Applying BMV Browser customizations..."

# App name
sed -i 's/>Iceraven Fenix</>BMV Browser</g' app/src/main/res/values/static_strings.xml
sed -i 's/>Iceraven</>BMV Browser</g' app/src/main/res/values/static_strings.xml

echo "BMV customizations applied."
