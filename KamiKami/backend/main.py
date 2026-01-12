from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import uuid
import os  # Necessário para ler a porta do servidor na nuvem

app = FastAPI()

# 1. Configuração de CORS Atualizada
# Isso permite que o seu link do Firebase acesse os dados do Python com segurança
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "https://kamikami-af5fe.web.app", # Seu link oficial
        "*" # Mantido para testes, mas o link acima é o principal
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modelos de Dados
class Item(BaseModel):
    nome: str
    preco: float

class Pedido(BaseModel):
    itens: List[Item]
    distancia_km: float

# Rota de Boas-vindas (para testar se a API está viva)
@app.get("/")
async def root():
    return {"status": "KamiKami API Online", "memoria": "Homenagem à Vó Lica"}

# 2. Rota do Cardápio
@app.get("/cardapio")
async def get_cardapio():
    return [
        {"nome": "Hambúrguer Gourmet", "preco": 35.00, "img": "🍔"},
        {"nome": "Pizza Artesanal", "preco": 55.00, "img": "🍕"},
        {"nome": "Batata Frita", "preco": 20.00, "img": "🍟"},
        {"nome": "Refrigerante 600ml", "preco": 8.00, "img": "🥤"},
    ]

# 3. Rota de Cálculo de Frete e Tempo
@app.get("/calcular-frete/{distancia_km}")
async def calcular_frete(distancia_km: float):
    taxa_base = 5.00
    valor_km = 2.00
    valor_frete = taxa_base + (distancia_km * valor_km)
    
    tempo_preparo = 20
    tempo_total = int(tempo_preparo + (distancia_km * 4))
    
    return {
        "frete": round(valor_frete, 2),
        "tempo": f"{tempo_total}-{tempo_total + 10} min"
    }

# 4. Rota de Checkout e Geração de Pix
@app.post("/checkout")
async def finalizar_pedido(pedido: Pedido):
    subtotal = sum(item.preco for item in pedido.itens)
    valor_frete = 5.00 + (pedido.distancia_km * 2.00)
    total = subtotal + valor_frete
    
    id_transacao = str(uuid.uuid4()).replace("-", "")[:10]
    pix_copia_e_cola = f"00020101021226850014BR.GOV.BCB.PIX0123kami{id_transacao}520400005303986540{total:.2f}5802BR5915KamiKami_Deliv6009SAO_PAULO62070503***6304"
    
    return {
        "subtotal": round(subtotal, 2),
        "frete": round(valor_frete, 2),
        "total": round(total, 2),
        "codigo_pix": pix_copia_e_cola,
        "qr_code_url": f"https://api.qrserver.com/v1/create-qr-code/?size=250x250&data={pix_copia_e_cola}",
        "status": "Aguardando Pagamento"
    }

# 5. Configuração para rodar na nuvem (Render/Railway)
if __name__ == "__main__":
    import uvicorn
    # O Render fornece a porta automaticamente pela variável de ambiente PORT
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)