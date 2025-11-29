import os
from flask import Flask

app = Flask(__name__)

# --- AQUÍ LEEMOS LO QUE MANDÓ N8N/TERRAFORM ---
# Si no llega nada, usa valores por defecto
BOT_NAME = os.getenv('BOT_NAME', 'Chatbot Genérico')
WELCOME_MSG = os.getenv('WELCOME_MESSAGE', 'Hola!')
PAYMENTS_ON = os.getenv('ENABLE_PAYMENTS', 'false') == 'true'
VIP_ON = os.getenv('ENABLE_VIP', 'false') == 'true'

@app.route('/')
def home():
    # Construimos la respuesta visual
    features_html = ""
    
    if PAYMENTS_ON:
        features_html += '<li style="color:green">✅ Módulo de Pagos: <b>ACTIVO</b> (Stripe Ready)</li>'
    else:
        features_html += '<li style="color:gray">❌ Módulo de Pagos: Inactivo</li>'
        
    if VIP_ON:
        features_html += '<li style="color:purple">✅ IA Lead Scoring: <b>ACTIVO</b> (Modo VIP)</li>'
    else:
        features_html += '<li style="color:gray">❌ IA Lead Scoring: Inactivo</li>'

    return f"""
    <div style="font-family: sans-serif; padding: 20px;">
        <h1>🤖 {BOT_NAME}</h1>
        <p>Estado del Sistema: <span style="color:green; font-weight:bold;">OPERATIVO</span></p>
        <hr>
        <h3>Configuración Actual:</h3>
        <p><b>Mensaje de Bienvenida:</b> "{WELCOME_MSG}"</p>
        <h3>Módulos Contratados:</h3>
        <ul>
            {features_html}
        </ul>
    </div>
    """

if __name__ == '__main__':
    # Correr en el puerto 5000 (Terraform luego mapea el 80 al 5000)
    app.run(host='0.0.0.0', port=5000)