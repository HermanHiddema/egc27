#!/bin/bash
cd /workspaces/egc27
rm -f tailwind.config.js
rm -rf app/assets/builds/tailwind*
bin/rails tailwindcss:build
echo "Tailwind CSS rebuilt successfully!"
