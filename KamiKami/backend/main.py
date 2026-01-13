from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import time
import hmac
import hashlib
import json

app = Flask(__name__)
CORS(app)

# CONFIGURAÇÕES LALAMOVE (Substitua pelas suas)
API_KEY = "SUA_API_KEY_AQUI"
API_SECRET = "SUA_API_SECRET_AQUI"
BASE_URL = "https://rest.lalamove.com" # Use 'https://rest.sandbox.lalamove.com' para testes

def gerar_assinatura_lalamove(method, path, body_str, timestamp):
    """Gera a assinatura de segurança exigida pela Lalamove"""
    raw_signature = f"{timestamp}\r\n{method}\r\n{path}\r\n\r\n{body_str}"
    signature = hmac.new(
        API_SECRET.encode(),
        raw_signature.encode(),
        hashlib.sha256
    ).hexdigest()
    return signature

@app.route('/cotar-mottu', methods=['POST']) # Mantive o nome da rota para não precisar mudar o Flutter
def cotar_entrega():
    dados = request.json
    endereco_destino = dados.get("endereco")
    
    timestamp = str(int(time.time() * 1000))
    path = '/v3/quotations'
    method = 'POST'
    
    payload = {
        "data": {
            "serviceType": "MOTORCYCLE",
            "language": "pt_BR",
            "stops": [
                {
                    "address": "Rua do KamiKami, 123, São Paulo, SP" # ENDEREÇO DA SUA LOJA
                },
                {
                    "address": endereco_destino # ENDEREÇO QUE O CLIENTE DIGITOU
                }
            ]
        }
    }
    
    body_str = json.dumps(payload)
    signature = gerar_assinatura_lalamove(method, path, body_str, timestamp)
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"hmac {API_KEY}:{timestamp}:{signature}",
        "Market": "BR"
    }

    try:
        response = requests.post(f"{BASE_URL}{path}", headers=headers, json=payload)
        res_data = response.json()
        
        if response.status_code == 201:
            # A Lalamove retorna o valor em uma string, convertemos para float
            valor_frete = float(res_data['data']['totalFee'])
            return jsonify({"frete": valor_frete})
        else:
            print(f"Erro Lalamove: {res_data}")
            return jsonify({"frete": 12.00, "aviso": "Usando frete fixo por erro na API"}), 200
    except Exception as e:
        print(f"Erro no servidor: {e}")
        return jsonify({"frete": 15.00}), 200

@app.route('/checkout', methods=['POST'])
def checkout():
    # Aqui continua sua lógica do Mercado Pago que já tínhamos
    # Integrando o valor do frete vindo do Flutter
    dados = request.json
    total_itens = sum(item['preco'] for item in dados['itens'])
    total_com_frete = total_itens + dados.get('frete', 0)
    
    # Simulação de resposta do Mercado Pago
    return jsonify({
        "qr_code_url": "https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=123",
        "total": total_com_frete
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)