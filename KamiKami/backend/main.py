from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import mercadopago
import os
import uvicorn

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# TOKEN DE TESTE (SANDBOX)
SDK = mercadopago.SDK("TEST-819053197713657-011222-194aeab4af602ac4782b61b245651ce7-181707904")

@app.post('/checkout')
async def checkout(request: Request):
    try:
        dados = await request.json()
        itens_carrinho = dados.get('itens', [])
        frete = dados.get('frete', 0)

        # Montagem rigorosa dos itens para evitar o erro "Ops"
        itens_pagamento = []
        for item in itens_carrinho:
            itens_pagamento.append({
                "title": str(item['nome']),
                "quantity": 1,
                "unit_price": float(item['preco']),
                "currency_id": "BRL"  # Moeda obrigatória
            })
        
        # Adiciona o frete como um item separado
        if float(frete) > 0:
            itens_pagamento.append({
                "title": "Taxa de Entrega KamiKami",
                "quantity": 1,
                "unit_price": float(frete),
                "currency_id": "BRL"
            })

        preference_data = {
            "items": itens_pagamento,
            "payment_methods": {
                "excluded_payment_types": [],
                "installments": 12
            },
            "back_urls": {
                "success": "https://kamikami-af5fe.web.app/#/sucesso",
                "failure": "https://kamikami-af5fe.web.app/#/erro",
                "pending": "https://kamikami-af5fe.web.app/#/pendente"
            },
            "auto_return": "approved",
            "binary_mode": True # Força aprovação ou reprovação imediata
        }

        result = SDK.preference().create(preference_data)
        
        # Pegando o ponto de início do Sandbox
        link_final = result["response"]["sandbox_init_point"]

        return {"qr_code_url": link_final}
        
    except Exception as e:
        print(f"Erro no Processamento: {str(e)}")
        return {"error": str(e)}, 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)