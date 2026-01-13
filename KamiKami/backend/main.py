from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import os
import mercadopago

app = FastAPI()

# 1. CONFIGURAÇÃO DE SEGURANÇA (CORS)
# Permite que o seu site no Firebase fale com o servidor no Render
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://kamikami-af5fe.web.app", "*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. INICIALIZAÇÃO DO MERCADO PAGO
# Ele busca o token que você cadastrou no painel 'Environment' do Render
sdk = mercadopago.SDK(os.environ.get("MP_ACCESS_TOKEN", "TOKEN_NAO_CONFIGURADO"))

# 3. MODELOS DE DADOS
class Item(BaseModel):
    nome: str
    preco: float

class Pedido(BaseModel):
    itens: List[Item]
    distancia_km: float

# 4. ROTAS DA API
@app.get("/")
async def root():
    return {"status": "KamiKami API Online", "homenagem": "Vó Lica"}

@app.get("/cardapio")
async def get_cardapio():
    return [
        {"nome": "Hambúrguer Gourmet", "preco": 35.00, "img": "🍔"},
        {"nome": "Pizza Artesanal", "preco": 55.00, "img": "🍕"},
        {"nome": "Batata Frita", "preco": 20.00, "img": "🍟"},
        {"nome": "Refrigerante 600ml", "preco": 8.00, "img": "🥤"},
    ]

@app.get("/calcular-frete/{distancia_km}")
async def calcular_frete(distancia_km: float):
    taxa_base = 5.00
    valor_km = 2.00
    valor_frete = taxa_base + (distancia_km * valor_km)
    tempo_total = int(20 + (distancia_km * 4))
    return {"frete": round(valor_frete, 2), "tempo": f"{tempo_total}-{tempo_total + 10} min"}

# 5. ROTA DE CHECKOUT (Gera o Pix Real)
@app.post("/checkout")
async def finalizar_pedido(pedido: Pedido):
    try:
        subtotal = sum(item.preco for item in pedido.itens)
        valor_frete = 5.00 + (pedido.distancia_km * 2.00)
        total = subtotal + valor_frete

        # Configura a cobrança para o Mercado Pago
        payment_data = {
            "transaction_amount": float(total),
            "description": "Pedido KamiKami Delivery",
            "payment_method_id": "pix",
            "payer": {
                "email": "cliente@kamikami.com", 
                "first_name": "Cliente",
                "last_name": "KamiKami"
            }
        }

        payment_response = sdk.payment().create(payment_data)
        payment = payment_response["response"]

        return {
            "total": round(total, 2),
            "codigo_pix": payment["point_of_interaction"]["transaction_data"]["qr_code"],
            "qr_code_url": payment["point_of_interaction"]["transaction_data"]["ticket_url"],
            "id_pagamento": payment["id"]
        }
    except Exception as e:
        print(f"Erro no checkout: {e}")
        raise HTTPException(status_code=500, detail="Falha ao gerar Pix")

# 6. ROTA DE WEBHOOK (Baixa Automática)
@app.post("/webhook")
async def receber_notificacao(request: Request):
    dados = await request.json()
    
    # O Mercado Pago avisa quando um pagamento muda de status
    if dados.get("type") == "payment":
        id_pagamento = dados["data"]["id"]
        resultado = sdk.payment().get(id_pagamento)
        status = resultado["response"]["status"]
        
        if status == "approved":
            print(f"💰 PAGAMENTO CONFIRMADO: Pedido {id_pagamento} no valor de R$ {resultado['response']['transaction_amount']}")
            # Aqui no futuro você pode salvar no banco de dados 'Pago: Sim'
            
    return {"status": "ok"}

# 7. INICIALIZAÇÃO DO SERVIDOR
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)