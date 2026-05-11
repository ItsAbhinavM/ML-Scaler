{{- define "yolo-service.name" -}}
yolo-service
{{- end -}}

{{- define "yolo-service.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "yolo-service.name" .) -}}
{{- end -}}
