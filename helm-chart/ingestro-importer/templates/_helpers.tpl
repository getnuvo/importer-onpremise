{{/*
Expand the name of the chart.
*/}}
{{- define "ingestro-importer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ingestro-importer.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart label.
*/}}
{{- define "ingestro-importer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/*
Common labels for every resource.
*/}}
{{- define "ingestro-importer.commonLabels" -}}
helm.sh/chart: {{ include "ingestro-importer.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- with .Values.global.extraLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels shared by every component.
*/}}
{{- define "ingestro-importer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ingestro-importer.fullname" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ include "ingestro-importer.componentSlug" (dict "component" .component) }}
{{- end -}}

{{/*
Component labels extend the selector labels.
*/}}
{{- define "ingestro-importer.componentLabels" -}}
{{ include "ingestro-importer.commonLabels" .root }}
{{ include "ingestro-importer.selectorLabels" . }}
{{- if .extra }}
{{ toYaml .extra }}
{{- end }}
{{- end -}}

{{/*
Name for the managed image pull secret.
*/}}
{{- define "ingestro-importer.imagePullSecretName" -}}
{{- if .Values.global.imageCredentials.name -}}
{{- .Values.global.imageCredentials.name -}}
{{- else -}}
{{- printf "%s-registry" (include "ingestro-importer.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Render imagePullSecrets for workloads.
*/}}
{{- define "ingestro-importer.imagePullSecrets" -}}
{{- $root := . -}}
{{- $secrets := list }}
{{- range $root.Values.global.imagePullSecrets }}
  {{- if kindIs "string" . }}
    {{- $secrets = append $secrets (dict "name" .) }}
  {{- else if and (kindIs "map" .) (.name) }}
    {{- $secrets = append $secrets (dict "name" .name) }}
  {{- end }}
{{- end }}
{{- if and $root.Values.global.imageCredentials.create ($root.Values.global.imageCredentials.password) }}
  {{- $secrets = append $secrets (dict "name" (include "ingestro-importer.imagePullSecretName" $root)) }}
{{- end }}
{{- if gt (len $secrets) 0 }}
imagePullSecrets:
{{- range $secrets }}
  - name: {{ .name }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Normalized component string for resource names.
*/}}
{{- define "ingestro-importer.componentSlug" -}}
{{- $component := .component | default "" -}}
{{- $slug := regexReplaceAll "[^a-z0-9]+" (lower $component) "-" -}}
{{- $trimmed := trimAll "-" $slug -}}
{{- if $trimmed -}}
{{- $trimmed -}}
{{- else -}}
component
{{- end -}}
{{- end -}}

{{/*
Return a component-scoped fullname with an optional suffix.
*/}}
{{- define "ingestro-importer.componentFullname" -}}
{{- $slug := include "ingestro-importer.componentSlug" (dict "component" .component) -}}
{{- $name := printf "%s-%s" (include "ingestro-importer.fullname" .root) $slug -}}
{{- if .suffix }}
{{- printf "%s-%s" $name .suffix | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the service account name for a component.
*/}}
{{- define "ingestro-importer.serviceAccountName" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $slug := include "ingestro-importer.componentSlug" (dict "component" $component) -}}
{{- $values := index $root.Values $component | default dict -}}
{{- $sa := $values.serviceAccount | default dict -}}
{{- if $sa.create | default false -}}
  {{- if $sa.name -}}
    {{- $sa.name -}}
  {{- else -}}
    {{- printf "%s-%s" (include "ingestro-importer.fullname" $root) $slug | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- else -}}
  {{- if $sa.name -}}
    {{- $sa.name -}}
  {{- else -}}
    default
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a hostname-based slug for resource naming.
*/}}
{{- define "ingestro-importer.hostSlug" -}}
{{- $host := default "" .host -}}
{{- $slug := regexReplaceAll "[^a-z0-9]+" (lower $host) "-" -}}
{{- $trimmed := trimAll "-" $slug -}}
{{- if $trimmed -}}
{{- $trimmed -}}
{{- else -}}
host
{{- end -}}
{{- end -}}

{{/*
Create a path-based slug for resource naming.
*/}}
{{- define "ingestro-importer.pathSlug" -}}
{{- $path := default "" .path -}}
{{- if eq $path "" -}}
path
{{- else -}}
{{- $slug := regexReplaceAll "[^a-z0-9]+" (lower $path) "-" -}}
{{- $trimmed := trimAll "-" $slug -}}
{{- if $trimmed -}}
{{- $trimmed -}}
{{- else -}}
path
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret name that should be referenced by a component.
*/}}
{{- define "ingestro-importer.secretName" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $values := index $root.Values $component | default dict -}}
{{- $secretRef := $values.secretRef | default dict -}}
{{- $existing := $secretRef.existingSecret | default "" -}}
{{- if $existing }}
  {{- $existing -}}
{{- else -}}
  {{- $external := $values.externalSecret | default dict -}}
  {{- $target := $external.target | default dict -}}
  {{- $defaultName := include "ingestro-importer.componentFullname" (dict "root" $root "component" $component "suffix" "secret") -}}
  {{- $targetName := default $defaultName $target.name -}}
  {{- if and ($external.enabled) $targetName }}
    {{- $targetName -}}
  {{- else -}}
    {{- $defaultName -}}
  {{- end -}}
{{- end -}}
{{- end -}}