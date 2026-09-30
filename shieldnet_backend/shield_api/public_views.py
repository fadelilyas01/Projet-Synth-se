from django.shortcuts import render

def help_center_view(request):
    """
    Centre d'assistance et FAQ public ShieldNet.
    Accessible sans authentification par l'application mobile et les abonnés.
    """
    return render(request, 'public/help_center.html', {
        'page_title': "Centre d'Assistance & FAQ"
    })
