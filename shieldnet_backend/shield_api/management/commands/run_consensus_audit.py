from django.core.management.base import BaseCommand
from shield_api.tasks import task_run_consensus_audit, task_decay_spam_scores, task_refresh_bloom_filter

class Command(BaseCommand):
    help = 'Exécute le calcul de consensus, decay des scores et rafraîchissement du filtre de Bloom'

    def handle(self, *args, **options):
        self.stdout.write('[ShieldNet] Exécution de l audit de consensus...')
        res_consensus = task_run_consensus_audit()
        self.stdout.write(self.style.SUCCESS(f'Consensus : {res_consensus}'))

        self.stdout.write('[ShieldNet] Ezécution du decay des+ scores...')
        res_decay = task_decay_spam_scores(half_life_days=30)
        self.stdout.write(self.style.SUCCESS(f'Decay : {res_decay}'))

        self.stdout.write('[ShieldNet] Rafraëchissement du filtre de Bloom...')
        res_bloom = task_refresh_bloom_filter()
        self.stdout.write(self.style.SUCCESS(f'Bloom : {res_bloom}'))
