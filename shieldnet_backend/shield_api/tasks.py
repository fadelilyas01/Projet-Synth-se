import math
import logging
from datetime import timedelta
from django.utils import timezone
from django.core.cache import caches

logger = logging.getLogger('shieldnet.tasks')

try:
    from celery import shared_task
except ImportError:
    def shared_task(func):
        func.delay = lambda *args, **kwargs: func(*args, **kwargs)
        return func

@shared_task
def task_run_consensus_audit():
    """
    Tâche asynchrone évaluant la consensualité des contestations
    pour réhabiliter automatiquement les faux positifs.
    """
    from .services import FalsePositiveConsensusService
    logger.info("Demarrage de l'audit de consensus...")
    result = FalsePositiveConsensusService.run_consensus_audit()
    return result

@shared_task
def task_decay_spam_scores(half_life_days=30):
    """
    Applique une décroissance exponentielle (demi-vie) aux scores de risque
    des numéros inactifs afin de prévenir le blocage de numéros recyclés.
    """
    from .models import BlacklistedNumber
    now = timezone.now()
    threshold_date = now - timedelta(days=half_life_days)
    decay_constant = math.log(2) / half_life_days

    candidates = BlacklistedNumber.objects.filter(
        is_blocked=True,
        is_whitelisted=False,
        updated_at__lt=threshold_date
    )

    decayed_count = 0
    unblocked_count = 0

    for num in candidates:
        days_inactive = (now - num.updated_at).total_seconds() / 86400.0
        decay_factor = math.exp(-decay_constant * (days_inactive - half_life_days))
        new_score = max(0, int(num.risk_score * decay_factor))

        if new_score != num.risk_score:
            num.risk_score = new_score
            if new_score < 40 and num.is_blocked:
                num.is_blocked = False
                unblocked_count += 1
            num.save(update_fields=['risk_score', 'is_blocked'])
            decayed_count += 1

    return {
        'decayed_count': decayed_count,
        'unblocked_count': unblocked_count,
    }

@shared_task
def task_refresh_bloom_filter(size_bits=65536):
    """
    Pré-calcule et met en cache mémoire le filtre de Bloom.
    """
    from .services import BloomFilterService
    payload = BloomFilterService.generate_filter_payload(size_bits=size_bits)
    try:
        caches['default'].set('shieldnet_bloom_filter_cache', payload, timeout=1800)
    except Exception as e:
        logger.warning(f"Impossible de cacher le filtre de Bloom : {e}")
    return {'status': 'success', 'entries_count': payload.get('entries_count', 0)}
