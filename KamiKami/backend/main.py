from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import requests
import time
import hmac
import hashlib
import json
import os

app = FastAPI()

# Configuração de CORS para o Flutter Web funcionar
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# CONFIGURAÇÕES LALAMOVE
API_KEY = "SUA_API_KEY_AQUI"
API_SECRET = "SUA_API_SECRET_AQUI"
BASE_URL = "https://rest.lalamove.com"

def gerar_assinatura_lalamove(method, path, body_str, timestamp):
    raw_signature = f"{timestamp}\r\n{method}\r\n{path}\r\n\r\n{body_str}"
    signature = hmac.new(
        API_SECRET.encode(),
        raw_signature.encode(),
        hashlib.sha256
    ).hexdigest()
    return signature

@app.post('/cotar-mottu') # Nome mantido para compatibilidade com seu Flutter
async def cotar_entrega(request: Request):
    try:
        dados = await request.json()
        endereco_destino = dados.get("endereco")
        
        # Se você ainda não tem as chaves da Lalamove, retornamos o Frete Fixo de R$ 7,00
        if API_KEY == "SUA_API_KEY_AQUI":
            return {"frete": 7.00, "modo": "Entrega Própria"}

        timestamp = str(int(time.time() * 1000))
        path = '/v3/quotations'
        method = 'POST'
        
        payload = {
            "data": {
                "serviceType": "MOTORCYCLE",
                "language": "pt_BR",
                "stops": [
                    {"address": "Rua do KamiKami, 123, São Paulo, SP"}, # ENDEREÇO DA SUA LOJA
                    {"address": endereco_destino}
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

        response = requests.post(f"{BASE_URL}{path}", headers=headers, json=payload)
        res_data = response.json()
        
        if response.status_code == 201:
            valor_frete = float(res_data['data']['totalFee'])
            return {"frete": valor_frete}
        else:
            return {"frete": 7.00, "aviso": "Erro na API, usando fixo"}
            
    except Exception as e:
        return {"frete": 7.00, "erro": str(e)}

@app.post('/checkout')
async def checkout(request: Request):
    dados = await request.json()
    
    # Cálculo do total
    total_itens = sum(item['preco'] for item in dados['itens'])
    frete = dados.get('frete', 0)
    total_com_frete = total_itens + frete
    
    # Aqui você deve inserir sua lógica real do Mercado Pago futuramente
    return {
        "qr_code_url": "https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=123",
        "total": total_com_frete
    }

if __name__ == "__main__":
    import uvicorn
    # Porta dinâmica para o Render
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)