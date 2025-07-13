{{/*
Expand the name of the chart.
*/}}
{{- define "spire.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "spire.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "spire.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spire.labels" -}}
helm.sh/chart: {{ include "spire.chart" . }}
{{ include "spire.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "spire.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spire.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
SPIRE Server labels
*/}}
{{- define "spire.server.labels" -}}
{{ include "spire.labels" . }}
app.kubernetes.io/component: spire-server
{{- end }}

{{/*
SPIRE Server selector labels
*/}}
{{- define "spire.server.selectorLabels" -}}
{{ include "spire.selectorLabels" . }}
app.kubernetes.io/component: spire-server
{{- end }}

{{/*
SPIRE Agent labels
*/}}
{{- define "spire.agent.labels" -}}
{{ include "spire.labels" . }}
app.kubernetes.io/component: spire-agent
{{- end }}

{{/*
SPIRE Agent selector labels
*/}}
{{- define "spire.agent.selectorLabels" -}}
{{ include "spire.selectorLabels" . }}
app.kubernetes.io/component: spire-agent
{{- end }}

{{/*
Create the name of the service account for SPIRE Server
*/}}
{{- define "spire.server.serviceAccountName" -}}
{{- if .Values.rbac.create }}
{{- default (printf "%s-server" (include "spire.fullname" .)) .Values.rbac.serviceAccount.spireServer }}
{{- else }}
{{- default "spire-server" .Values.rbac.serviceAccount.spireServer }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account for SPIRE Agent
*/}}
{{- define "spire.agent.serviceAccountName" -}}
{{- if .Values.rbac.create }}
{{- default (printf "%s-agent" (include "spire.fullname" .)) .Values.rbac.serviceAccount.spireAgent }}
{{- else }}
{{- default "spire-agent" .Values.rbac.serviceAccount.spireAgent }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account for workload services
*/}}
{{- define "spire.workload.serviceAccountName" -}}
{{- if .Values.rbac.create }}
{{- default (printf "%s-workload" (include "spire.fullname" .)) .Values.rbac.serviceAccount.workloadServices }}
{{- else }}
{{- default "workload-service" .Values.rbac.serviceAccount.workloadServices }}
{{- end }}
{{- end }}

{{/*
Create image name
*/}}
{{- define "spire.image" -}}
{{- $registry := .registry | default .global.imageRegistry }}
{{- printf "%s/%s:%s" $registry .repository .tag }}
{{- end }}

{{/*
Trust domain
*/}}
{{- define "spire.trustDomain" -}}
{{- .Values.global.trustDomain | default "example.org" }}
{{- end }}

{{/*
PostgreSQL connection string
*/}}
{{- define "spire.postgresql.connectionString" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgres://%s:%s@%s-postgresql:5432/%s?sslmode=disable" .Values.postgresql.auth.username .Values.postgresql.auth.password .Release.Name .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.externalDatabase.connectionString }}
{{- end }}
{{- end }}

{{/*
SPIRE Server address for agents
*/}}
{{- define "spire.server.address" -}}
{{- printf "%s-server.%s.svc.cluster.local" .Release.Name .Release.Namespace }}
{{- end }}