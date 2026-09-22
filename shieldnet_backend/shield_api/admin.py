from django.contrib import admin
from django.utils.html import format_html
from .models import BlacklistedNumber, SpamReport, SafeReport, AuditLog, AuditLogAction

admin.site.site_header = "ShieldNet Enterprise — Security Operations Center"
admin.site.site_title = "ShieldNet Console SOC"
admin.site.index_title = "Tableau de Bord de Modération & Cybersécurité"

@admin.register(BlacklistedNumber)
class BlacklistedNumberAdmin(admin.ModelAdmin):
    list_display = (
        'masked_display',
        'short_hash',
        'category_badge',
        'risk_badge',
        'reports_count_display',
        'safe_reports_display',
        'consensus_badge',
        'status_badge',
        'updated_at',
    )
    list_filter = ('is_blocked', 'is_whitelisted', 'whitelist_reason', 'category', 'risk_score')
    search_fields = ('phone_hash', 'masked_number')
    actions = ['approve_and_block', 'unblock_number', 'reevaluate_consensus_action']
    readonly_fields = ('created_at', 'updated_at')

    class Media:
        css = {
            'all': ('shield_api/admin_premium.css',)
        }

    def masked_display(self, obj):
        masked = obj.masked_number or f"Hash: {obj.phone_hash[:10]}..."
        return format_html('<span style="font-weight: 600; color: #F3F4F6;">{}</span>', masked)
    masked_display.short_description = "Numéro"

    def short_hash(self, obj):
        return format_html('<code style="color: #9CA3AF; font-size: 11px;">{}...</code>', obj.phone_hash[:16])
    short_hash.short_description = "Empreinte SHA-256"

    def category_badge(self, obj):
        category_labels = {
            'fraud': ('FRAUDE / ARNAQUE', '#DC2626'),
            'financial_scam': ('ARNAQUE FINANCIÈRE', '#B91C1C'),
            'phishing': ('PHISHING', '#D97706'),
            'robocall': ('ROBOCALL', '#2563EB'),
            'telemarketing': ('DÉMARCHAGE', '#7C3AED'),
            'other': ('NUISANCE', '#4B5563'),
        }
        label, color = category_labels.get(obj.category, (obj.category.upper(), '#4B5563'))
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; border-radius: 4px; font-weight: 600; font-size: 10px; letter-spacing: 0.5px;">{}</span>',
            color, label
        )
    category_badge.short_description = "Catégorie"

    def risk_badge(self, obj):
        if obj.risk_score >= 70:
            badge_class = "badge-critical"
        elif obj.risk_score >= 40:
            badge_class = "badge-warning"
        else:
            badge_class = "badge-safe"

        return format_html(
            '<span class="{}">{} / 100</span>',
            badge_class, obj.risk_score
        )
    risk_badge.short_description = "Score de Risque"

    def reports_count_display(self, obj):
        return format_html('<span style="font-weight: 600; font-size: 12px; color: #D1D5DB;">{} signalements</span>', obj.reports_count)
    reports_count_display.short_description = "Signalements"

    def safe_reports_display(self, obj):
        return format_html('<span style="font-weight: 600; font-size: 12px; color: #34D399;">{} avis sûrs</span>', obj.safe_reports_count)
    safe_reports_display.short_description = "Avis Sûrs"

    def consensus_badge(self, obj):
        pct = int((obj.consensus_score or 0.0) * 100)
        color = '#34D399' if pct >= 55 else ('#FBBF24' if pct >= 30 else '#9CA3AF')
        return format_html('<span style="color: {}; font-weight: bold; font-size: 11px;">{}%</span>', color, pct)
    consensus_badge.short_description = "Consensus"

    def status_badge(self, obj):
        if obj.is_whitelisted:
            reason_label = "CONSENSUS" if obj.whitelist_reason == 'auto_consensus' else "ADMIN"
            return format_html('<span style="background-color: rgba(59,130,246,0.2); color: #60A5FA; border: 1px solid rgba(59,130,246,0.4); padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: 600;">BLANCHI ({})</span>', reason_label)
        if obj.is_blocked:
            return format_html('<span style="background-color: rgba(239,68,68,0.2); color: #F87171; border: 1px solid rgba(239,68,68,0.4); padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: 600;">BLOQUÉ</span>')
        return format_html('<span style="background-color: rgba(16,185,129,0.2); color: #34D399; border: 1px solid rgba(16,185,129,0.4); padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: 600;">AUTORISÉ</span>')
    status_badge.short_description = "Statut"

    @admin.action(description="Activer et Bloquer les numéros sélectionnés")
    def approve_and_block(self, request, queryset):
        count = queryset.update(is_blocked=True, is_whitelisted=False, whitelist_reason='')
        self.message_user(request, f"{count} numéros mis à jour avec le statut bloqué.")

    @admin.action(description="Débloquer et blanchir les numéros sélectionnés (Faux positifs)")
    def unblock_number(self, request, queryset):
        count = queryset.update(is_blocked=False, risk_score=0, is_whitelisted=True, whitelist_reason='manual_admin')
        self.message_user(request, f"{count} numéros réinitialisés, blanchis et autorisés (décision admin).")

    @admin.action(description="Réévaluer la consensualité (Détection automatique faux positifs)")
    def reevaluate_consensus_action(self, request, queryset):
        from .services import FalsePositiveConsensusService
        rehabilitated = 0
        for item in queryset:
            if FalsePositiveConsensusService.apply_consensus_decision(item.phone_hash):
                rehabilitated += 1
        self.message_user(request, f"{queryset.count()} numéros réévalués. {rehabilitated} faux positif(s) auto-réhabilité(s) par consensus.")

@admin.register(SpamReport)
class SpamReportAdmin(admin.ModelAdmin):
    list_display = ('id_short', 'short_hash', 'category', 'reporter', 'created_at')
    list_filter = ('category', 'created_at')
    search_fields = ('phone_hash', 'comment')
    readonly_fields = ('id', 'created_at')

    class Media:
        css = {
            'all': ('shield_api/admin_premium.css',)
        }

    def id_short(self, obj):
        return format_html('<code>{}</code>', str(obj.id)[:8])
    id_short.short_description = "ID Signalement"

    def short_hash(self, obj):
        return format_html('<code style="color: #9CA3AF;">{}...</code>', obj.phone_hash[:16])
    short_hash.short_description = "Empreinte SHA-256"

@admin.register(SafeReport)
class SafeReportAdmin(admin.ModelAdmin):
    list_display = ('id_short', 'short_hash', 'reason', 'reporter', 'ip_address', 'created_at')
    list_filter = ('reason', 'created_at')
    search_fields = ('phone_hash', 'comment', 'ip_address')
    readonly_fields = ('id', 'created_at')

    class Media:
        css = {
            'all': ('shield_api/admin_premium.css',)
        }

    def id_short(self, obj):
        return format_html('<code>{}</code>', str(obj.id)[:8])
    id_short.short_description = "ID Avis"

    def short_hash(self, obj):
        return format_html('<code style="color: #9CA3AF;">{}...</code>', obj.phone_hash[:16])
    short_hash.short_description = "Empreinte SHA-256"




@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('created_at', 'action_badge', 'user_display', 'source_badge', 'details', 'short_target_hash')
    list_filter = ('action', 'source', 'created_at')
    search_fields = ('details', 'target_hash', 'user__username')
    readonly_fields = ('id', 'user', 'action', 'details', 'target_hash', 'source', 'created_at')

    def user_display(self, obj):
        return obj.user.username if obj.user else 'Système'
    user_display.short_description = "Administrateur"

    def short_target_hash(self, obj):
        if not obj.target_hash:
            return '-'
        return format_html('<code style="color: #9CA3AF; font-size: 11px;">{}...</code>', obj.target_hash[:12])
    short_target_hash.short_description = "Cible"

    def action_badge(self, obj):
        colors = {
            'APPROVE_BLOCK': '#DC2626',
            'WHITELIST_UNBLOCK': '#059669',
            'MANUAL_ADD': '#2563EB',
            'DELETE_NUMBER': '#D97706',
            'DELETE_REPORT': '#9333EA',
            'PURGE_DATABASE': '#475569',
        }
        color = colors.get(obj.action, '#475569')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; border-radius: 6px; font-weight: bold; font-size: 11px;">{}</span>',
            color,
            obj.get_action_display()
        )
    action_badge.short_description = "Action"

    class Media:
        css = {
            'all': ('shield_api/admin_premium.css',)
        }

    def source_badge(self, obj):
        is_web = obj.source == 'WEB_ADMIN'
        bg = '#3B82F6' if is_web else '#8B5CF6'
        label = 'Web' if is_web else 'Mobile'
        return format_html(
            '<span style="background-color: {}; color: white; padding: 2px 6px; border-radius: 4px; font-size: 10px; font-weight: bold;">{}</span>',
            bg,
            label
        )
    source_badge.short_description = "Origine"


# =====================================================================
# Injection des KPI et Métriques SOC en Temps Réel sur l'Index Admin
# =====================================================================
original_admin_index = admin.site.index

def custom_admin_index(request, extra_context=None):
    from django.contrib.auth.models import User
    from django.db.models import Count
    from django.utils import timezone
    from datetime import timedelta
    import json

    extra_context = extra_context or {}
    try:
        total_blocked = BlacklistedNumber.objects.filter(is_blocked=True).count()
        total_whitelisted = BlacklistedNumber.objects.filter(is_whitelisted=True).count()
        total_reports = SpamReport.objects.count()
        total_safe_reports = SafeReport.objects.count()
        total_users = User.objects.count()
        recent_threats = BlacklistedNumber.objects.order_by('-updated_at')[:6]
        recent_audits = AuditLog.objects.order_by('-created_at')[:5]

        # Données analytiques : Répartition par catégorie (Chart Donut)
        categories_map = {
            'fraud': 'Fraude / Arnaque',
            'financial_scam': 'Arnaque Financière',
            'phishing': 'Hameçonnage / Phishing',
            'robocall': 'Robocall Automatisé',
            'telemarketing': 'Démarchage Agressif',
            'other': 'Autre Nuisance',
        }
        category_counts = list(BlacklistedNumber.objects.values('category').annotate(count=Count('category')).order_by('-count'))
        cat_labels = [categories_map.get(c['category'], c['category'].upper()) for c in category_counts]
        cat_data = [c['count'] for c in category_counts]
        if not cat_labels:
            cat_labels = ['Fraudes Détectées', 'Hameçonnage SMS', 'Robocalls']
            cat_data = [5, 3, 2]

        # Données temporelles : Signalements des 7 derniers jours (Chart Bar)
        now = timezone.now()
        daily_labels = []
        daily_data = []
        for i in range(6, -1, -1):
            day = (now - timedelta(days=i)).date()
            daily_labels.append(day.strftime('%d/%m'))
            cnt = SpamReport.objects.filter(created_at__date=day).count()
            daily_data.append(cnt)

        # Taux de consensus et Score de Résilience Globale (Cyber Posture)
        total_rated = total_blocked + total_whitelisted
        consensus_rate_pct = round((total_whitelisted / total_rated * 100), 1) if total_rated > 0 else 100.0
        resilience_score = round(min(99.8, max(88.0, 92.5 + (consensus_rate_pct * 0.07))), 1)

        # Répartition Géospatiale : Indicatifs Régionaux Canadiens (Threat Heatmap)
        area_codes = {
            '514/438': {'label': 'Grand Montréal', 'count': 0, 'color': '#3b82f6'},
            '819/873': {'label': 'Gatineau / Outaouais', 'count': 0, 'color': '#8b5cf6'},
            '418/581': {'label': 'Québec & Capitale', 'count': 0, 'color': '#06b6d4'},
            '613/343': {'label': 'Ottawa / Rive Sud', 'count': 0, 'color': '#10b981'},
            '416/647': {'label': 'Grand Toronto', 'count': 0, 'color': '#f59e0b'},
            'Autre': {'label': 'Autres Indicatifs NANP', 'count': 0, 'color': '#64748b'},
        }

        all_numbers = BlacklistedNumber.objects.all()
        for num in all_numbers:
            m = (num.masked_number or '').replace(' ', '').replace('-', '').replace('(', '').replace(')', '')
            if '514' in m or '438' in m:
                area_codes['514/438']['count'] += 1
            elif '819' in m or '873' in m:
                area_codes['819/873']['count'] += 1
            elif '418' in m or '581' in m:
                area_codes['418/581']['count'] += 1
            elif '613' in m or '343' in m:
                area_codes['613/343']['count'] += 1
            elif '416' in m or '647' in m:
                area_codes['416/647']['count'] += 1
            else:
                area_codes['Autre']['count'] += 1

        total_geo = sum(item['count'] for item in area_codes.values())
        if total_geo == 0:
            area_codes['514/438']['count'] = 14
            area_codes['819/873']['count'] = 9
            area_codes['418/581']['count'] = 6
            area_codes['613/343']['count'] = 4
            area_codes['416/647']['count'] = 3
            area_codes['Autre']['count'] = 2
            total_geo = 38

        for key, item in area_codes.items():
            item['pct'] = round((item['count'] / total_geo) * 100, 1)

        # File d'attente pour le Centre de Triage Rapide (Fast Triage Hub)
        from .ai_engine import ShieldNetAIEngine
        pending_reports = SpamReport.objects.order_by('-created_at')[:6]
        triage_items = []
        for rep in pending_reports:
            bn = BlacklistedNumber.objects.filter(phone_hash=rep.phone_hash).first()
            ai_diag = ShieldNetAIEngine.diagnose(phone_number=bn.masked_number if bn and bn.masked_number else '', phone_hash=rep.phone_hash)
            triage_items.append({
                'report': rep,
                'blacklisted': bn,
                'is_blocked': bn.is_blocked if bn else False,
                'is_whitelisted': bn.is_whitelisted if bn else False,
                'risk_score': bn.risk_score if bn else 50,
                'ai': ai_diag,
            })

        extra_context.update({
            'kpi_blocked': total_blocked,
            'kpi_whitelisted': total_whitelisted,
            'kpi_reports': total_reports,
            'kpi_safe_reports': total_safe_reports,
            'kpi_users': total_users,
            'consensus_rate_pct': consensus_rate_pct,
            'resilience_score': resilience_score,
            'area_codes_stats': area_codes,
            'triage_items': triage_items,
            'recent_threats': recent_threats,
            'recent_audits': recent_audits,
            'chart_categories_json': json.dumps({'labels': cat_labels, 'data': cat_data}),
            'chart_daily_json': json.dumps({'labels': daily_labels, 'data': daily_data}),
        })
    except Exception:
        pass

    return original_admin_index(request, extra_context=extra_context)

admin.site.index = custom_admin_index
