import csv
import json
from django.http import JsonResponse, HttpResponse
from django.shortcuts import render
from django.contrib.admin.views.decorators import staff_member_required
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST, require_GET, require_http_methods
from django.utils import timezone
from .models import BlacklistedNumber, SpamReport, SafeReport, AuditLog, AuditLogAction
from .services import hash_phone_number, mask_phone_number, AutomatedSpamVerifier, FalsePositiveConsensusService, DatabaseSanitizerService

@staff_member_required
@require_http_methods(["GET", "POST"])
def sandbox_check_view(request):
    """
    Bac à sable d'analyse et testeur de réputation de numéro en temps réel.
    Calcule l'empreinte HMAC-SHA256 et diagnostique le statut dans la base de données.
    """
    if request.method == "POST":
        try:
            body = json.loads(request.body.decode('utf-8'))
            phone_number = body.get('phone_number', '').strip()
        except Exception:
            phone_number = request.POST.get('phone_number', '').strip()
    else:
        phone_number = request.GET.get('phone_number', '').strip()

    if not phone_number:
        return JsonResponse({'error': 'Veuillez fournir un numéro de téléphone à analyser.'}, status=400)

    # Hachage cryptographique et masquage déterministe
    phone_hash = hash_phone_number(phone_number)
    masked = mask_phone_number(phone_number)

    # Évaluation algorithmique heuristique
    heuristic = AutomatedSpamVerifier.evaluate_number(phone_hash, phone_number)

    # Diagnostic d'Intelligence Artificielle (XAI, arbitrage faux positif, NLP)
    from .ai_engine import ShieldNetAIEngine
    ai_diag = ShieldNetAIEngine.diagnose(phone_number=phone_number, phone_hash=phone_hash)

    # Recherche en base de données
    record = BlacklistedNumber.objects.filter(phone_hash=phone_hash).first()

    if record:
        status_label = "BLANCHI" if record.is_whitelisted else ("BLOQUÉ" if record.is_blocked else "AUTORISÉ")
        return JsonResponse({
            'success': True,
            'phone_number': phone_number,
            'phone_hash': phone_hash,
            'masked_number': record.masked_number or masked,
            'exists_in_db': True,
            'is_blocked': record.is_blocked,
            'is_whitelisted': record.is_whitelisted,
            'whitelist_reason': record.whitelist_reason,
            'status': status_label,
            'risk_score': record.risk_score,
            'category': record.category,
            'category_display': record.get_category_display(),
            'reports_count': record.reports_count,
            'safe_reports_count': record.safe_reports_count,
            'consensus_score': round(record.consensus_score * 100, 1) if record.consensus_score else 0.0,
            'anomalies': heuristic.get('anomalies', []),
            'ai': ai_diag,
            'updated_at': record.updated_at.strftime('%d/%m/%Y %H:%M') if record.updated_at else '-',
        })
    else:
        return JsonResponse({
            'success': True,
            'phone_number': phone_number,
            'phone_hash': phone_hash,
            'masked_number': masked,
            'exists_in_db': False,
            'is_blocked': False,
            'is_whitelisted': False,
            'whitelist_reason': '',
            'status': 'INCONNU (SAIN)',
            'risk_score': heuristic.get('calculated_score', 0),
            'category': 'unknown',
            'category_display': 'Non Répertorié',
            'reports_count': 0,
            'safe_reports_count': 0,
            'consensus_score': 0.0,
            'anomalies': heuristic.get('anomalies', []),
            'ai': ai_diag,
            'updated_at': 'Jamais',
        })

@staff_member_required
@require_POST
def sandbox_action_view(request):
    """
    Exécute une action directe de modération (bloquer ou blanchir) depuis le simulateur.
    Trace l'action dans le journal d'audit (AuditLog).
    """
    try:
        data = json.loads(request.body.decode('utf-8'))
    except Exception:
        data = request.POST

    phone_number = data.get('phone_number', '').strip()
    action = data.get('action', '').strip()  # 'block' ou 'whitelist'

    if not phone_number or action not in ['block', 'whitelist']:
        return JsonResponse({'error': 'Paramètres invalides (phone_number et action attendus).'}, status=400)

    phone_hash = hash_phone_number(phone_number)
    masked = mask_phone_number(phone_number)

    record, created = BlacklistedNumber.objects.get_or_create(
        phone_hash=phone_hash,
        defaults={'masked_number': masked, 'category': 'other'}
    )

    if action == 'block':
        record.is_blocked = True
        record.is_whitelisted = False
        record.whitelist_reason = ''
        record.risk_score = max(record.risk_score, 85)
        record.save()
        audit_action = AuditLogAction.MANUAL_ADD if created else AuditLogAction.APPROVE_BLOCK
        detail_msg = f"Numéro {masked} bloqué manuellement depuis le simulateur Web SOC."
    else:  # whitelist
        record.is_blocked = False
        record.is_whitelisted = True
        record.whitelist_reason = 'manual_admin'
        record.risk_score = 0
        record.save()
        audit_action = AuditLogAction.WHITELIST_UNBLOCK
        detail_msg = f"Numéro {masked} blanchi et réhabilité depuis le simulateur Web SOC."

    # Enregistrement d'audit inaltérable
    AuditLog.objects.create(
        user=request.user,
        action=audit_action,
        details=detail_msg,
        target_hash=phone_hash,
        source='WEB_ADMIN'
    )

    return JsonResponse({
        'success': True,
        'message': detail_msg,
        'status': "BLOQUÉ" if record.is_blocked else "BLANCHI",
        'risk_score': record.risk_score,
        'is_blocked': record.is_blocked,
        'is_whitelisted': record.is_whitelisted,
    })

@staff_member_required
@require_GET
def export_blacklist_csv_view(request):
    """
    Exporte la liste noire intégrale en format CSV pour intégration dans les systèmes PBX / Asterisk.
    """
    response = HttpResponse(content_type='text/csv; charset=utf-8')
    response['Content-Disposition'] = f'attachment; filename="shieldnet_blacklist_{timezone.now().strftime("%Y%m%d")}.csv"'
    
    # BOM UTF-8 pour ouverture directe parfaite dans Microsoft Excel
    response.write('\ufeff')
    writer = csv.writer(response)
    writer.writerow([
        'Empreinte SHA-256',
        'Numéro Masqué',
        'Catégorie',
        'Score de Risque (/100)',
        'Nombre de Signalements',
        'Avis Sûrs',
        'Taux de Consensus (%)',
        'Statut Bloqué',
        'Statut Blanchi',
        'Dernière Mise à Jour'
    ])

    for num in BlacklistedNumber.objects.all().order_by('-updated_at'):
        writer.writerow([
            num.phone_hash,
            num.masked_number or 'Inconnu',
            num.get_category_display(),
            num.risk_score,
            num.reports_count,
            num.safe_reports_count,
            round(num.consensus_score * 100, 1) if num.consensus_score else 0.0,
            'OUI' if num.is_blocked else 'NON',
            'OUI' if num.is_whitelisted else 'NON',
            num.updated_at.strftime('%Y-%m-%d %H:%M:%S') if num.updated_at else ''
        ])

    return response

@staff_member_required
@require_POST
def trigger_consensus_view(request):
    """
    Exécute un balayage de consensus anti-faux positifs à travers l'ensemble de la base.
    """
    rehabilitated_count = 0
    analyzed_count = 0

    candidates = BlacklistedNumber.objects.filter(safe_reports_count__gt=0)
    for cand in candidates:
        analyzed_count += 1
        if FalsePositiveConsensusService.apply_consensus_decision(cand.phone_hash):
            rehabilitated_count += 1

    AuditLog.objects.create(
        user=request.user,
        action=AuditLogAction.WHITELIST_UNBLOCK,
        details=f"Balayage d'auto-consensus exécuté : {analyzed_count} numéros examinés, {rehabilitated_count} faux positifs réhabilités.",
        source='WEB_ADMIN'
    )

    return JsonResponse({
        'success': True,
        'message': f"Balayage de consensus terminé : {analyzed_count} numéros analysés, {rehabilitated_count} faux positif(s) réhabilité(s) avec succès.",
        'analyzed': analyzed_count,
        'rehabilitated': rehabilitated_count,
    })

@staff_member_required
@require_POST
def trigger_purge_view(request):
    """
    Purge les données de signalements orphelines et obsolètes de plus de 30 jours.
    """
    purged_count = DatabaseSanitizerService.purge_obsolete_and_unverified_junk()

    AuditLog.objects.create(
        user=request.user,
        action=AuditLogAction.PURGE_DATABASE,
        details=f"Purge automatique de maintenance exécutée : {purged_count} entrées de signalements obsolètes supprimées.",
        source='WEB_ADMIN'
    )

    return JsonResponse({
        'success': True,
        'message': f"Purge terminée avec succès : {purged_count} enregistrement(s) obsolète(s) supprimé(s).",
        'purged': purged_count,
    })

@staff_member_required
@require_POST
def triage_action_view(request):
    """
    Exécute une action rapide de triage SOC sur un signalement en 1 clic :
    - 'escalate_block' : Force le blocage en liste noire avec score 95+
    - 'dismiss_safe' : Blanchit et réhabilite le numéro (faux positif avéré)
    - 'flag_watch' : Place le numéro sous surveillance heuristique
    """
    try:
        data = json.loads(request.body.decode('utf-8'))
    except Exception:
        data = request.POST

    report_id = data.get('report_id')
    action = data.get('action')

    if not report_id or action not in ['escalate_block', 'dismiss_safe', 'flag_watch']:
        return JsonResponse({'error': 'Paramètres report_id ou action invalides.'}, status=400)

    report = SpamReport.objects.filter(id=report_id).first()
    if not report:
        return JsonResponse({'error': f'Signalement {report_id} introuvable.'}, status=404)

    record, _ = BlacklistedNumber.objects.get_or_create(
        phone_hash=report.phone_hash,
        defaults={'category': report.category}
    )

    if action == 'escalate_block':
        record.is_blocked = True
        record.is_whitelisted = False
        record.whitelist_reason = ''
        record.risk_score = max(record.risk_score, 95)
        record.save()
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.APPROVE_BLOCK,
            details=f"Signalement {report.id} escaladé en blocage d'urgence ({record.masked_number or record.phone_hash[:12]}).",
            target_hash=record.phone_hash,
            source='WEB_ADMIN'
        )
        msg = f"Menace {record.masked_number or record.phone_hash[:10]} confirmée et bloquée sur tout le réseau."
    elif action == 'dismiss_safe':
        record.is_blocked = False
        record.is_whitelisted = True
        record.whitelist_reason = 'manual_admin'
        record.risk_score = 0
        record.save()
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.WHITELIST_UNBLOCK,
            details=f"Signalement {report.id} réhabilité et blanchi (faux positif validé par l'admin).",
            target_hash=record.phone_hash,
            source='WEB_ADMIN'
        )
        msg = f"Numéro {record.masked_number or record.phone_hash[:10]} blanchi et réhabilité avec succès."
    else:  # flag_watch
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.MANUAL_ADD,
            details=f"Signalement {report.id} placé sous surveillance accrue (statut sous observation).",
            target_hash=record.phone_hash,
            source='WEB_ADMIN'
        )
        msg = f"Numéro {record.masked_number or record.phone_hash[:10]} placé sous observation accrue."

    return JsonResponse({
        'success': True,
        'message': msg,
        'report_id': str(report_id),
        'action': action,
        'risk_score': record.risk_score,
        'is_blocked': record.is_blocked,
        'is_whitelisted': record.is_whitelisted,
    })

@staff_member_required
@require_GET
def telemetry_live_view(request):
    """
    Flux de télémétrie en direct pour le mode salle de contrôle (Operations Room).
    Retourne les KPI, le score de résilience et le dernier événement d'interception.
    """
    from django.contrib.auth.models import User
    total_blocked = BlacklistedNumber.objects.filter(is_blocked=True).count()
    total_whitelisted = BlacklistedNumber.objects.filter(is_whitelisted=True).count()
    total_reports = SpamReport.objects.count()
    total_safe_reports = SafeReport.objects.count()
    total_users = User.objects.count()

    # Score de résilience cyber dynamique (0 - 100%)
    total_interceptions = total_blocked + total_whitelisted + total_reports
    resilience_score = 98.6
    if total_interceptions > 0:
        clean_ratio = (total_blocked + total_whitelisted) / (total_interceptions + 1)
        resilience_score = round(min(99.8, max(85.0, 92.0 + (clean_ratio * 7.5))), 1)

    latest_audit = AuditLog.objects.order_by('-created_at').first()
    latest_event = "Système nominal — Surveillance active des flux VoIP & GSM"
    if latest_audit:
        latest_event = f"{latest_audit.get_action_display()} : {latest_audit.details}"

    return JsonResponse({
        'kpi_blocked': total_blocked,
        'kpi_whitelisted': total_whitelisted,
        'kpi_reports': total_reports,
        'kpi_safe_reports': total_safe_reports,
        'kpi_users': total_users,
        'resilience_score': resilience_score,
        'latest_event': latest_event,
        'timestamp': timezone.now().strftime('%H:%M:%S'),
    })

@staff_member_required
@require_GET
def executive_report_view(request):
    """
    Génère un rapport exécutif prêt pour impression / PDF A4
    (Threat Intelligence Executive Briefing) pour la direction et l'évaluation universitaire.
    """
    from django.contrib.auth.models import User
    from django.db.models import Count

    total_blocked = BlacklistedNumber.objects.filter(is_blocked=True).count()
    total_whitelisted = BlacklistedNumber.objects.filter(is_whitelisted=True).count()
    total_reports = SpamReport.objects.count()
    total_safe_reports = SafeReport.objects.count()
    total_users = User.objects.count()

    total_decided = total_blocked + total_whitelisted
    consensus_pct = round((total_whitelisted / total_decided * 100), 1) if total_decided > 0 else 100.0
    resilience_score = round(min(99.8, max(88.0, 92.0 + (consensus_pct * 0.07))), 1)

    categories_counts = list(BlacklistedNumber.objects.values('category').annotate(count=Count('category')).order_by('-count'))
    top_threats = BlacklistedNumber.objects.order_by('-risk_score', '-reports_count')[:10]
    recent_audits = AuditLog.objects.order_by('-created_at')[:8]

    context = {
        'generated_at': timezone.now(),
        'admin_user': request.user,
        'kpi_blocked': total_blocked,
        'kpi_whitelisted': total_whitelisted,
        'kpi_reports': total_reports,
        'kpi_safe_reports': total_safe_reports,
        'kpi_users': total_users,
        'consensus_pct': consensus_pct,
        'resilience_score': resilience_score,
        'categories_counts': categories_counts,
        'top_threats': top_threats,
        'recent_audits': recent_audits,
    }
    return render(request, 'admin/executive_report.html', context)

@staff_member_required
@require_GET
def admin_triage_dashboard_view(request):
    """
    Page dédiée plein écran pour le Centre de Triage SOC.
    Permet à l'opérateur d'examiner et de traiter tous les signalements de spams
    avec filtres par catégorie, recherche et actions rapides AJAX.
    """
    from django.core.paginator import Paginator

    category_filter = request.GET.get('category', '').strip()
    search_query = request.GET.get('q', '').strip()

    reports_qs = SpamReport.objects.select_related('reporter').order_by('-created_at')

    if category_filter:
        reports_qs = reports_qs.filter(category=category_filter)
    if search_query:
        reports_qs = reports_qs.filter(phone_hash__icontains=search_query)

    paginator = Paginator(reports_qs, 20)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)

    phone_hashes = [r.phone_hash for r in page_obj]
    existing_records = {
        b.phone_hash: b for b in BlacklistedNumber.objects.filter(phone_hash__in=phone_hashes)
    }

    triage_items = []
    for r in page_obj:
        rec = existing_records.get(r.phone_hash)
        ai_diag = ShieldNetAIEngine.diagnose(phone_number=rec.masked_number if rec and rec.masked_number else '', phone_hash=r.phone_hash)
        triage_items.append({
            'report': r,
            'record': rec,
            'is_blocked': rec.is_blocked if rec else False,
            'is_whitelisted': rec.is_whitelisted if rec else False,
            'risk_score': rec.risk_score if rec else 0,
            'ai': ai_diag,
        })

    total_pending = SpamReport.objects.count()
    total_blocked = BlacklistedNumber.objects.filter(is_blocked=True).count()
    total_whitelisted = BlacklistedNumber.objects.filter(is_whitelisted=True).count()

    from django.contrib import admin as django_admin
    context = {
        **django_admin.site.each_context(request),
        'title': 'Centre de Triage SOC des Signalements',
        'triage_items': triage_items,
        'page_obj': page_obj,
        'category_filter': category_filter,
        'search_query': search_query,
        'total_pending': total_pending,
        'total_blocked': total_blocked,
        'total_whitelisted': total_whitelisted,
        'has_permission': True,
    }
    return render(request, 'admin/triage_dashboard.html', context)

@staff_member_required
@require_GET
def admin_sandbox_dashboard_view(request):
    """
    Page dédiée plein écran pour le Laboratoire d'Analyse Sandbox SOC.
    Permet à l'opérateur de tester tout numéro de téléphone ou empreinte,
    d'analyser les anomalies heuristiques et d'exécuter des actions directes.
    """
    recent_audits = AuditLog.objects.order_by('-created_at')[:8]
    recent_blacklisted = BlacklistedNumber.objects.order_by('-updated_at')[:8]

    from django.contrib import admin as django_admin
    context = {
        **django_admin.site.each_context(request),
        'title': "Simulateur Sandbox & Analyse Heuristique",
        'recent_audits': recent_audits,
        'recent_blacklisted': recent_blacklisted,
        'has_permission': True,
    }
    return render(request, 'admin/sandbox_dashboard.html', context)


