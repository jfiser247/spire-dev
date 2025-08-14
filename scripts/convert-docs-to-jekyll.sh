#!/bin/bash

# Convert docs to Jekyll format with proper front matter

DOCS_DIR="docs"
PAGES_DIR="_pages"

# Create pages directory if it doesn't exist
mkdir -p "$PAGES_DIR"

# Define mappings of filename to Jekyll permalink and title
declare -A doc_mappings
doc_mappings["quick_start_workload_integration.md"]="quick-start-workload-integration,Quick Start Workload Integration"
doc_mappings["troubleshooting.md"]="troubleshooting,Troubleshooting Setup"
doc_mappings["spiffe_service_integration_guide.md"]="spiffe-service-integration,SPIFFE Service Integration Guide"
doc_mappings["workload_integration_guide.md"]="workload-integration,Workload Integration Guide"
doc_mappings["architecture_diagrams.md"]="architecture-diagrams,Understanding Architecture"
doc_mappings["project_structure.md"]="project-structure,Project Structure"
doc_mappings["architecture_validation.md"]="architecture-validation,Architecture Validation"
doc_mappings["spire_security_policies.md"]="security-policies,Security Policy Requirements"
doc_mappings["enterprise_architecture_diagram.md"]="enterprise-architecture,Enterprise Architecture"
doc_mappings["enterprise_deployment_guide.md"]="enterprise-deployment,Production Deployment Guide"
doc_mappings["enterprise_workload_integration.md"]="enterprise-workload-integration,Enterprise Integration"
doc_mappings["helm_deployment_guide.md"]="helm-deployment,Helm Charts Guide"
doc_mappings["enterprise_crd_requirements.md"]="enterprise-crd-requirements,CRD Requirements"

echo "Converting documentation files to Jekyll format..."

for file in "${!doc_mappings[@]}"; do
    if [[ -f "$DOCS_DIR/$file" ]]; then
        IFS=',' read -r permalink title <<< "${doc_mappings[$file]}"
        
        # Extract filename without extension for Jekyll filename
        basename="${file%.*}"
        
        echo "Converting $file -> $PAGES_DIR/${permalink}.md"
        
        # Create Jekyll page with front matter
        cat > "$PAGES_DIR/${permalink}.md" << EOF
---
layout: page
title: $title
permalink: /$permalink/
---

EOF
        
        # Append original content (skip first line if it's a title)
        tail -n +2 "$DOCS_DIR/$file" >> "$PAGES_DIR/${permalink}.md"
        
        # Fix internal links to use Jekyll format
        sed -i '' 's/(\([^)]*\)\.md)/(\{{ "\/\1\/" | relative_url }})/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/quick_start_workload_integration/quick-start-workload-integration/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/spiffe_service_integration_guide/spiffe-service-integration/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/workload_integration_guide/workload-integration/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/architecture_diagrams/architecture-diagrams/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/project_structure/project-structure/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/architecture_validation/architecture-validation/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/spire_security_policies/security-policies/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/enterprise_architecture_diagram/enterprise-architecture/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/enterprise_deployment_guide/enterprise-deployment/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/enterprise_workload_integration/enterprise-workload-integration/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/helm_deployment_guide/helm-deployment/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/enterprise_crd_requirements/enterprise-crd-requirements/g' "$PAGES_DIR/${permalink}.md"
        sed -i '' 's/troubleshooting/troubleshooting/g' "$PAGES_DIR/${permalink}.md"
        
    else
        echo "Warning: $DOCS_DIR/$file not found"
    fi
done

echo "Jekyll documentation conversion complete!"
echo "Generated pages in $PAGES_DIR/"