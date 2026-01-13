from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import uuid
import os
import mercadopago

app = FastAPI()

# Configuração de CORS para o seu link do Firebase
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://kamikami-af5fe.web.app", "*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inicializa o Mercado Pago usando a variável que você salvou no Render
# Certifique-se de que a chave no Render seja: MP_ACCESS_TOKEN
sdk = mercadopago.SDK(os.environ.get("MP_ACCESS_TOKEN", "TOKEN_NAO_CONFIGURADO"))

class Item(BaseModel):
    nome: str
    preco: float

class Pedido(BaseModel):
    itens: List[Item]
    distancia_km: float

@app.get("/")
async def root():
    return {"status": "KamiKami API Online", "integracao": "Mercado Pago Ativo"}

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

# ROTA DE CHECKOUT ATUALIZADA (Gera Pix Real)
@app.post("/checkout")
async def finalizar_pedido(pedido: Pedido):
    try:
        subtotal = sum(item.preco for item in pedido.itens)
        valor_frete = 5.00 + (pedido.distancia_km * 2.00)
        total = subtotal + valor_frete

        # Dados para o Mercado Pago
        payment_data = {
            "transaction_amount": float(total),
            "description": "Pedido KamiKami Delivery",
            "payment_method_id": "pix",
            "payer": {
                "email": "cliente@kamikami.com", # Pode ser dinâmico depois
                "first_name": "Cliente",
                "last_name": "KamiKami"
            }
        }

        # Cria o pagamento no Mercado Pago
        payment_response = sdk.payment().create(payment_data)
        payment = payment_response["response"]

        # Retorna o QR Code Real e o Código Copia e Cola
        return {
            "subtotal": round(subtotal, 2),
            "frete": round(valor_frete, 2),
            "total": round(total, 2),
            "codigo_pix": payment["point_of_interaction"]["transaction_data"]["qr_code"],
            "qr_code_url": payment["point_of_interaction"]["transaction_data"]["ticket_url"],
            "status": "Aguardando Pagamento"
        }
    except Exception as e:
        print(f"Erro no Mercado Pago: {e}")
        raise HTTPException(status_code=500, detail="Erro ao gerar pagamento")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)