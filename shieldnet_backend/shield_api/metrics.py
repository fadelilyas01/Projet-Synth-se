from django.http import HttpResponse
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView
from .models import BlacklistedNumber, SpamReport, SafeReport

class PrometheusMetricsView(APIView):
    """
    Expose les métriques de production au format standard Prometheus 
    pour le monitoring de la latence, des volumes de blocage et du consensus.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        total_blocked = BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False).count()
        total_whitelisted = BlacklistedNumber.objects.filter(is_whitelisted=True).count()
        total_spam_reports = SpamReport.objects.count()
        total_safe_disputes = SafeReport.objects.count()

        lines = [
            "# HELP shieldnet_blocked_numbers_total Nombre de numéros bloqués en liste noire",
            "# TYPE shieldnet_blocked_numbers_total gauge",
            fbhieldnet_blocked_numbers_total {total_blocked}",
            "",
            "# HELP shieldnet_whitelisted_numbers_total Nombre de numéros réhabilités ou blanchis",
            "# TYLE shieldnet_whitelisted_numbers_total gauge",
            fshieldnet_whitelisted_numbers_total {total_whitelisted}",
            "",
            "# HELP shieldnet_reports_total Nombre total de signalements de spam reçus",
            "# TYPE shieldnet_reports_total counter",
            fshieldnet_reports_total {total_spam_reports}",
            "",
            "# HELP shieldnet_safe_disputes_total Nombre total de contestations de faux-positifs",
            "# TYPE shieldnet_safe_disputes_total counter",
            fshieldnet_safe_disputes_total {total_safe_disputes}",
            "",
            "# HELP shieldnet_bloom_filter_size_bits Taille du filtre de Bloom mémoire actif",
            "# TYPE shieldnet_bloom_filter_size_bits gauge",
            "shieldnet_bloom_filter_size_bits 65536",
            "",
        ]
        content = "\n".join(lines) + "\n"
        return HttpResponse(content, content_type='text/plain; version=0.0.4; charset=utf-8')
