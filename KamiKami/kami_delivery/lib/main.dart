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
  
  // URL OFICIAL DO SEU BACKEND NO RENDER
  final String urlBase = "https://kamikami-backend.onrender.com";

  // 1. Lógica de Localização e Frete
  Future<void> calcularFreteAutomatico() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      Position position = await Geolocator.getCurrentPosition();
      
      // Coordenadas fictícias do restaurante (ajuste conforme necessário)
      double distanciaKM = Geolocator.distanceBetween(-23.5505, -46.6333, position.latitude, position.longitude) / 1000;

      try {
        // CORREÇÃO: Usando a URL oficial do Render e a rota correta
        final response = await http.get(Uri.parse('$urlBase/calcular-frete/${distanciaKM.toStringAsFixed(2)}'));
        
        if (response.statusCode == 200) {
          var dados = json.decode(response.body);
          setState(() {
            frete = dados['frete'].toDouble();
            tempoEntrega = dados['tempo'];
          });
        }
      } catch (e) {
        debugPrint("Erro ao ligar para o Render: $e");
        setState(() => tempoEntrega = "Erro ao calcular");
      }
    }
  }

  double get total => carrinho.fold(0.0, (sum, item) => sum + double.parse(item['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'))) + frete;

  // 2. Lógica de Checkout (Gera Pix no Render)
  Future<void> processarCheckoutPix() async {
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      Position pos = await Geolocator.getCurrentPosition();
      double km = Geolocator.distanceBetween(-23.5505, -46.6333, pos.latitude, pos.longitude) / 1000;
      
      List itens = carrinho.map((i) => {
        "nome": i['nome'], 
        "preco": double.parse(i['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'))
      }).toList();

      // CORREÇÃO: Enviando para a rota /checkout correta no Render
      final response = await http.post(
        Uri.parse('$urlBase/checkout'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"itens": itens, "distancia_km": km}),
      );

      if (!mounted) return;
      Navigator.pop(context); // Fecha o loading

      if (response.statusCode == 200) {
        var dados = json.decode(response.body);
        exibirModalPix(dados['codigo_pix'], dados['qr_code_url'], dados['total'].toDouble());
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Erro no checkout: $e");
    }
  }

  // 3. Modal do Pix e WhatsApp
  void exibirModalPix(String codigo, String urlQr, double totalFinal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Pagamento via Pix", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Image.network(urlQr, height: 200),
            const SizedBox(height: 16),
            const Text("Copia e Cola:", style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(codigo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 24),
            Text("Total: R\$ ${totalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => enviarWhatsApp(totalFinal, codigo),
              child: const Text("Paguei! Enviar Comprovante", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void enviarWhatsApp(double total, String pix) async {
    // Altere para o seu número real com DDD
    String msg = Uri.encodeComponent("*Novo Pedido KamiKami*\nTotal: R\$ ${total.toStringAsFixed(2)}\nPix: $pix");
    var url = Uri.parse("https://wa.me/5511999999999?text=$msg"); 
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
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
          onPressed: () => processarCheckoutPix(), 
          child: const Text("FECHAR PEDIDO", style: TextStyle(color: Colors.white))
        )
      ]),
    );
  }
}