#!/bin/bash
# validate-templates.sh - Validate CloudFormation templates

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 CloudFormation Template Validation${NC}"
echo

# Find all CloudFormation templates
TEMPLATES=$(find cloudformation -name "*.yaml" -o -name "*.yml")

if [ -z "$TEMPLATES" ]; then
    echo -e "${RED}❌ No CloudFormation templates found in cloudformation/${NC}"
    exit 1
fi

# Validate each template
for template in $TEMPLATES; do
    echo -n "Validating $template... "
    
    if aws cloudformation validate-template --template-body file://$template > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Valid${NC}"
    else
        echo -e "${RED}❌ Invalid${NC}"
        echo "Error details:"
        aws cloudformation validate-template --template-body file://$template 2>&1 || true
        exit 1
    fi
done

echo
echo -e "${GREEN}🎉 All templates are valid!${NC}"