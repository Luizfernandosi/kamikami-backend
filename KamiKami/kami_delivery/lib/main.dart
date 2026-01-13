import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MaterialApp(home: AppCliente(), debugShowCheckedModeBanner: false));

class AppCliente extends StatefulWidget {
  const AppCliente({super.key});
  @override
  _AppClienteState createState() => _AppClienteState();
}

class _AppClienteState extends State<AppCliente> {
  List carrinho = [];
  double frete = 0.00;
  String tempoEntrega = "Calculando...";
  
  // URL DO SEU BACKEND NO RENDER
  final String urlBase = "https://kamikami-backend.onrender.com";

  Future<void> calcularFreteAutomatico() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      Position? position;

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        ).catchError((e) => null); 
      }
      
      // Ajuste as coordenadas abaixo para o endereço real do seu restaurante
      double distanciaKM = (position != null) 
          ? Geolocator.distanceBetween(-23.5505, -46.6333, position.latitude, position.longitude) / 1000
          : 5.0;

      final response = await http.get(
        Uri.parse('$urlBase/calcular-frete/${distanciaKM.toStringAsFixed(2)}')
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        var dados = json.decode(response.body);
        setState(() {
          frete = dados['frete'].toDouble();
          tempoEntrega = dados['tempo'];
        });
      }
    } catch (e) {
      setState(() {
        frete = 10.00;
        tempoEntrega = "30-45 min (Aprox.)";
      });
    }
  }

  double get total => carrinho.fold(0.0, (sum, item) => sum + double.parse(item['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'))) + frete;

  // CHECKOUT PRO: Integração com múltiplas formas de pagamento
  Future<void> processarCheckout() async {
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      double km = 5.0;
      try {
        Position? pos = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 4)).catchError((e) => null);
        if (pos != null) km = Geolocator.distanceBetween(-23.5505, -46.6333, pos.latitude, pos.longitude) / 1000;
      } catch (_) {}
      
      List itens = carrinho.map((i) => {
        "nome": i['nome'], 
        "preco": double.parse(i['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'))
      }).toList();

      final response = await http.post(
        Uri.parse('$urlBase/checkout'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"itens": itens, "distancia_km": km}),
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;
      Navigator.pop(context); 

      if (response.statusCode == 200) {
        var dados = json.decode(response.body);
        // Agora recebemos o link da preferência (init_point) do Mercado Pago
        exibirModalPagamento(dados['qr_code_url'], dados['total'].toDouble());
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Erro no checkout: $e");
    }
  }

  void exibirModalPagamento(String urlPagamento, double totalFinal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, size: 50, color: Colors.blue),
            const Text("Finalizar Pedido", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text("Escolha como pagar (Pix, Cartão ou Boleto):", textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, 
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () => launchUrl(Uri.parse(urlPagamento), mode: LaunchMode.externalApplication),
              child: const Text("PAGAR COM MERCADO PAGO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text("Total: R\$ ${totalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text("Ambiente Seguro Mercado Pago", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
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
          if (carrinho.isNotEmpty) containerResumo(),
        ],
      ),
    );
  }

  Widget itemCard(String nome, String preco, String img) {
    return Card(child: ListTile(
      leading: Text(img, style: const TextStyle(fontSize: 30)),
      title: Text(nome), subtitle: Text(preco),
      trailing: IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange), onPressed: () {
        setState(() => carrinho.add({'nome': nome, 'preco': preco}));
        if (frete == 0) calcularFreteAutomatico();
      }),
    ));
  }

  Widget containerResumo() {
    return Container(
      padding: const EdgeInsets.all(16), color: Colors.grey[100],
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Frete:"), Text("R\$ ${frete.toStringAsFixed(2)}")]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Entrega:"), Text(tempoEntrega)]),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold)), Text("R\$ ${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)), 
          onPressed: () => processarCheckout(), 
          child: const Text("FECHAR PEDIDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        )
      ]),
    );
  }
}