from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List

app = FastAPI()

# Configuração de CORS para permitir que o Flutter (Frontend) acesse a API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modelo de dados para o Pedido
class Item(BaseModel):
    nome: str
    preco: float

class Pedido(BaseModel):
    itens: List[Item]
    distancia_km: float

# 1. Rota do Cardápio (Dinamizada)
@app.get("/cardapio")
async def get_cardapio():
    return [
        {"nome": "Hambúrguer Gourmet", "preco": 35.00, "img": "🍔"},
        {"nome": "Pizza Artesanal", "preco": 55.00, "img": "🍕"},
        {"nome": "Batata Frita", "preco": 20.00, "img": "🍟"},
        {"nome": "Refrigerante 600ml", "preco": 8.00, "img": "🥤"},
    ]

# 2. Rota de Checkout (Cálculo de Frete e Tempo)
@app.post("/checkout")
async def finalizar_pedido(pedido: Pedido):
    # Lógica de Frete: R$ 5,00 fixo + R$ 2,00 por KM
    taxa_base = 5.00
    valor_km = 2.00
    valor_frete = taxa_base + (pedido.distancia_km * valor_km)
    
    # Lógica de Tempo: 20 min (preparo) + 4 min por KM
    tempo_preparo = 20
    tempo_deslocamento = pedido.distancia_km * 4
    tempo_total_estimado = int(tempo_preparo + tempo_deslocamento)

    subtotal = sum(item.preco for item in pedido.itens)
    
    return {
        "subtotal": round(subtotal, 2),
        "frete": round(valor_frete, 2),
        "total": round(subtotal + valor_frete, 2),
        "tempo_estimado": f"{tempo_total_estimado}-{tempo_total_estimado + 10} min",
        "status": "Aguardando Pagamento"
    }