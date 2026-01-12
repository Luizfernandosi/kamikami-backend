import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: AppCliente(), debugShowCheckedModeBanner: false));

class AppCliente extends StatefulWidget {
  const AppCliente({super.key});
  @override
  _AppClienteState createState() => _AppClienteState();
}

class _AppClienteState extends State<AppCliente> {
  List carrinho = [];
  double frete = 7.00;
  String tempoEntrega = "30-45 min";

  double get total => carrinho.fold(0, (sum, item) => sum + double.parse(item['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'))) + frete;

  void adicionarAoCarrinho(produto) {
    setState(() => carrinho.add(produto));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${produto['nome']} no carrinho!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KamiKami Delivery'), backgroundColor: Colors.orange),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                itemCard('Hambúrguer Gourmet', 'R\$ 35,00', '🍔'),
                itemCard('Pizza Artesanal', 'R\$ 55,00', '🍕'),
              ],
            ),
          ),
          // Barra de Resumo de Pedido
          if (carrinho.isNotEmpty) containerResumo(),
        ],
      ),
    );
  }

  Widget itemCard(nome, preco, img) {
    return Card(
      child: ListTile(
        leading: Text(img, style: const TextStyle(fontSize: 30)),
        title: Text(nome),
        subtitle: Text(preco),
        trailing: IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange), onPressed: () => adicionarAoCarrinho({'nome': nome, 'preco': preco})),
      ),
    );
  }

  Widget containerResumo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Frete:"), Text("R\$ ${frete.toStringAsFixed(2)}")]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Entrega:"), Text(tempoEntrega)]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold)), Text("R\$ ${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
            onPressed: () => mostrarPagamento(),
            child: const Text("FECHAR PEDIDO", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void mostrarPagamento() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Escolha o Pagamento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListTile(leading: const Icon(Icons.pix, color: Colors.blue), title: const Text("Pix (Ganhe 5% OFF)"), onTap: () {}),
            ListTile(leading: const Icon(Icons.credit_card), title: const Text("Cartão de Crédito"), onTap: () {}),
          ],
        ),
      ),
    );
  }
}