from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import uuid

class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='BlacklistedNumber',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('phone_hash', models.CharField(db_index=True, help_text='Empreinte SHA-256 anonymisée du numéro de téléphone', max_length=64, unique=True)),
                ('masked_number', models.CharField(blank=True, help_text='Numéro partiellement masqué pour affichage admin (ex: +1 819 *** **67)', max_length=30, null=True)),
                ('category', models.CharField(choices=[('fraud', 'Fraude / Arnaque'), ('telemarketing', 'Démarchage commercial'), ('financial_scam', 'Arnaque financière'), ('phishing', 'Hameçonnage / Phishing'), ('robocall', 'Appel automatisé / Robocall'), ('other', 'Autre nuisance')], default='fraud', max_length=30)),
                ('risk_score', models.IntegerField(default=0, help_text='Score de réputation calculé de 0 (faible) à 100 (extrême)')),
                ('reports_count', models.IntegerField(default=1, help_text='Nombre total de signalements croisés')),
                ('is_blocked', models.BooleanField(default=True, help_text='Indique si le numéro est actif dans la liste noire diffusée au mobile')),
                ('is_whitelisted', models.BooleanField(default=False, help_text="Indique si le numéro a été blanchi / approuvé par un administrateur (faux positif)")),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Numéro Indésirable',
                'verbose_name_plural': 'Liste Noire Globale',
                'ordering': ['-risk_score', '-reports_count'],
            },
        ),
        migrations.CreateModel(
            name='SpamReport',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('phone_hash', models.CharField(db_index=True, max_length=64)),
                ('category', models.CharField(choices=[('fraud', 'Fraude / Arnaque'), ('telemarketing', 'Démarchage commercial'), ('financial_scam', 'Arnaque financière'), ('phishing', 'Hameçonnage / Phishing'), ('robocall', 'Appel automatisé / Robocall'), ('other', 'Autre nuisance')], max_length=30)),
                ('comment', models.TextField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('reporter', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='spam_reports', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Signalement utilisateur',
                'verbose_name_plural': 'Signalements communautaires',
                'ordering': ['-created_at'],
            },
        ),
    ]
