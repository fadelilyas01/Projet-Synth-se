import re
from rest_framework import serializers
from .models import BlacklistedNumber, SpamReport, SafeReport, SafeReasonChoices, AuditLog

class BlacklistedNumberSerializer(serializers.ModelSerializer):
    """
    Sérialiseur pour la liste noire diffusée à l'application mobile.
    """
    class Meta:
        model = BlacklistedNumber
        fields = [
            'phone_hash',
            'masked_number',
            'category',
            'risk_score',
            'reports_count',
            'safe_reports_count',
            'consensus_score',
            'is_whitelisted',
            'whitelist_reason',
            'updated_at',
        ]

class SpamReportCreateSerializer(serializers.Serializer):
    """
    Sérialiseur pour la soumission d'un nouveau signalement anonymisé.
    """
    phone_hash = serializers.CharField(max_length=64, min_length=64)
    masked_number = serializers.CharField(max_length=30, required=False, allow_blank=True)
    category = serializers.ChoiceField(choices=BlacklistedNumber._meta.get_field('category').choices)
    comment = serializers.CharField(required=False, allow_blank=True)

    def validate_phone_hash(self, value):
        # Vérification stricte du format SHA-256 (64 caractères hexadécimaux)
        if not re.match(r'^[a-fA-F0-9]{64}$', value):
            raise serializers.ValidationError("L'empreinte phone_hash doit être un hash SHA-256 hexadécimal valide de 64 caractères.")
        return value.lower()

class SafeReportCreateSerializer(serializers.Serializer):
    """
    Sérialiseur pour la soumission d'un avis favorable ou contestation de faux positif.
    """
    phone_hash = serializers.CharField(max_length=64, min_length=64)
    masked_number = serializers.CharField(max_length=30, required=False, allow_blank=True)
    reason = serializers.ChoiceField(choices=SafeReasonChoices.choices, default=SafeReasonChoices.LEGITIMATE_SERVICE)
    comment = serializers.CharField(required=False, allow_blank=True)

    def validate_phone_hash(self, value):
        if not re.match(r'^[a-fA-F0-9]{64}$', value):
            raise serializers.ValidationError("L'empreinte phone_hash doit être un hash SHA-256 hexadécimal valide de 64 caractères.")
        return value.lower()

class SafeReportSerializer(serializers.ModelSerializer):
    reporter_email = serializers.SerializerMethodField()

    class Meta:
        model = SafeReport
        fields = ['id', 'phone_hash', 'reason', 'comment', 'reporter_email', 'created_at']

    def get_reporter_email(self, obj):
        return obj.reporter.email if obj.reporter else 'Anonyme'

class CheckNumberResponseSerializer(serializers.Serializer):
    is_spam = serializers.BooleanField()
    risk_score = serializers.IntegerField()
    category = serializers.CharField(allow_null=True)
    reports_count = serializers.IntegerField()
    safe_reports_count = serializers.IntegerField(default=0)
    consensus_score = serializers.FloatField(default=0.0)
    is_whitelisted = serializers.BooleanField(default=False)
    whitelist_reason = serializers.CharField(allow_null=True, required=False)

from django.contrib.auth.models import User

class UserSerializer(serializers.ModelSerializer):
    name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'email', 'name', 'is_staff', 'is_superuser', 'date_joined']

    def get_name(self, obj):
        full_name = f"{obj.first_name} {obj.last_name}".strip()
        return full_name if full_name else (obj.email.split('@')[0] if obj.email else obj.username)

class UserRegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=6)
    name = serializers.CharField(required=False, allow_blank=True, default='')

    def validate_email(self, value):
        email_clean = value.strip().lower()
        if User.objects.filter(email__iexact=email_clean).exists() or User.objects.filter(username__iexact=email_clean).exists():
            raise serializers.ValidationError("Cet email est déjà associé à un compte.")
        return email_clean

    def create(self, validated_data):
        email = validated_data['email']
        password = validated_data['password']
        name = validated_data.get('name', '').strip()
        first_name = name.split()[0] if name else ''
        last_name = ' '.join(name.split()[1:]) if len(name.split()) > 1 else ''

        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
        )
        return user

class EmailLoginSerializer(serializers.Serializer):
    email = serializers.CharField()  # Accepte soit l'email soit le username (ex: admin)
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        email = data.get('email', '').strip().lower()
        password = data.get('password')

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            user = User.objects.filter(username__iexact=email).first()

        if not user:
            raise serializers.ValidationError("Aucun compte n'existe avec cet email. Veuillez créer un compte ou vous connecter avec Google.")

        if not user.check_password(password):
            raise serializers.ValidationError("Mot de passe incorrect.")

        if not user.is_active:
            raise serializers.ValidationError("Ce compte utilisateur est inactif.")

        data['user'] = user
        return data

class GoogleLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    name = serializers.CharField(required=False, allow_blank=True, default='')
    id_token = serializers.CharField(required=False, allow_blank=True, default='')

    def validate_email(self, value):
        return value.strip().lower()



class AuditLogSerializer(serializers.ModelSerializer):
    username = serializers.SerializerMethodField()

    class Meta:
        model = AuditLog
        fields = [
            'id',
            'user',
            'username',
            'action',
            'details',
            'target_hash',
            'source',
            'created_at',
        ]

    def get_username(self, obj):
        return obj.user.username if obj.user else 'Système'
