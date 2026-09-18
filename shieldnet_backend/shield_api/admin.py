from django.contrib import admin
from django.utils.html import format_html
from .models import BlacklistedNumber, SpamReport, SafeReport, AuditLog, AuditLogAction

admin.site.site_header = "ShieldNet Enterprise — Administration Console"
admin.site.site_title = "ShieldNet Console"
admin.site.index_title = "Modération & Contrôle de Réputation"

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
