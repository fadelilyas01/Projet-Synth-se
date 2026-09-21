import csv
import json
from django.http import JsonResponse, HttpResponse
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
