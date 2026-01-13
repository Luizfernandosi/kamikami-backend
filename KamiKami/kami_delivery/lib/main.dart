import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
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
  Map<String, Map<String, dynamic>> carrinhoMap = {};
  double frete = 0.00;
  TextEditingController enderecoController = TextEditingController();
  bool enderecoValidado = false;
  
  // CONFIGURAÇÕES GERAIS
  final Color corLaranja = const Color(0xFFFF944D); 
  final Color corPreta = const Color(0xFF1A1A1A);
  final String urlBase = "https://kamikami-backend.onrender.com";
  final String googleApiKey = "AIzaSyD6Ajve0QZkljEZ0387rQLBxNh8-BpnZPU"; // Sua Chave Google

  double get total {
    double subtotal = 0;
    carrinhoMap.forEach((key, value) {
      double preco = double.parse(value['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'));
      subtotal += preco * value['qtd'];
    });
    return subtotal + frete;
  }

  void adicionarAoCarrinho(String nome, String preco) {
    setState(() {
      if (carrinhoMap.containsKey(nome)) {
        carrinhoMap[nome]!['qtd']++;
      } else {
        carrinhoMap[nome] = {'preco': preco, 'qtd': 1};
      }
    });
  }

  void removerDoCarrinho(String nome) {
    setState(() {
      if (carrinhoMap.containsKey(nome)) {
        if (carrinhoMap[nome]!['qtd'] > 1) {
          carrinhoMap[nome]!['qtd']--;
        } else {
          carrinhoMap.remove(nome);
        }
      }
    });
  }

  // CHAMADA PARA O BACKEND (LALAMOVE)
  Future<void> validarEnderecoLalamove(String endereco, StateSetter setModalState) async {
    setModalState(() => enderecoValidado = false);
    try {
      final response = await http.post(
        Uri.parse('$urlBase/cotar-mottu'), // Rota mantida conforme main.py
        headers: {"Content-Type": "application/json"},
        body: json.encode({"endereco": endereco}),
      );
      if (response.statusCode == 200) {
        var dados = json.decode(response.body);
        setState(() => frete = dados['frete'].toDouble());
        setModalState(() => enderecoValidado = true);
      }
    } catch (e) {
      setState(() => frete = 12.00); 
      setModalState(() => enderecoValidado = true);
    }
  }

  void abrirAbaFinalizacao() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("FINALIZAR PAGAMENTO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 15),
                
                // AUTOCOMPLETE DO GOOGLE PLACES
                GooglePlaceAutoCompleteTextField(
                  textEditingController: enderecoController,
                  googleAPIKey: googleApiKey,
                  inputDecoration: InputDecoration(
                    labelText: "Digite seu endereço completo",
                    prefixIcon: const Icon(Icons.search, color: Colors.orange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      onPressed: () async {
                        LatLng? result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TelaSelecaoMapa()),
                        );
                        if (result != null) {
                          // Simula endereço por coordenadas ou chama Geocoding aqui
                          enderecoController.text = "Localização via Mapa";
                          validarEnderecoLalamove("Lat: ${result.latitude}, Lng: ${result.longitude}", setModalState);
                        }
                      },
                    ),
                  ),
                  countries: const ["br"],
                  isReadyOTP: true,
                  itemClick: (Prediction prediction) {
                    enderecoController.text = prediction.description!;
                    validarEnderecoLalamove(prediction.description!, setModalState);
                  },
                ),
                
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal:"), Text("R\$ ${(total - frete).toStringAsFixed(2)}")]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Entrega (Lalamove):"), Text("R\$ ${frete.toStringAsFixed(2)}", style: const TextStyle(color: Colors.blue))]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("R\$ ${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.green))]),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enderecoValidado ? Colors.blue : Colors.grey,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: enderecoValidado ? () => processarCheckoutReal() : null,
                  child: const Text("PAGAR COM MERCADO PAGO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> processarCheckoutReal() async {
    List itens = [];
    carrinhoMap.forEach((k, v) => itens.add({"nome": k, "preco": double.parse(v['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'))}));
    
    final response = await http.post(
      Uri.parse('$urlBase/checkout'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"itens": itens, "endereco": enderecoController.text, "frete": frete}),
    );
    
    if (response.statusCode == 200) {
      var dados = json.decode(response.body);
      await launchUrl(Uri.parse(dados['qr_code_url']), mode: LaunchMode.externalApplication);
      
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => PaginaStatus(endereco: enderecoController.text, total: total)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("KAMI KAMI YAKISSOBA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: corPreta),
      body: Column(
        children: [
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), color: corLaranja, child: const Text("MENU COMPLETO", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView(
              children: [
                itemMenu('01 - CARNE', 'R\$ 29,90', '🥩', 'Carne+Legumes+Verduras Tradicionais (440g)'),
                itemMenu('02 - MISTO', 'R\$ 28,90', '🍱', 'Carne e Frango+Legumes+Verduras (440g)'),
                itemMenu('03 - FRANGO', 'R\$ 27,90', '🍗', 'Frango+Legumes+Verduras Tradicionais (440g)'),
                itemMenu('04 - LEGUMES', 'R\$ 26,90', '🥦', 'Legumes+Verduras Tradicionais (440g)'),
                itemMenu('05 - CAMARÃO', 'R\$ 34,90', '🍤', 'Camarão+Legumes+Verduras Tradicionais (440g)'),
                itemMenu('06 - TEMAKI SALMÃO', 'R\$ 30,90', '🍣', 'Salmão Fresco, Cream Cheese e Cebolinha'),
                const Divider(),
                itemMenu('MACARRÃO ADICIONAL', 'R\$ 7,50', '🍜', 'Porção extra de macarrão'),
                itemMenu('LEGUMES ADICIONAL', 'R\$ 7,50', '🥗', 'Porção extra de legumes'),
                const SizedBox(height: 100),
              ],
            ),
          ),
          if (carrinhoMap.isNotEmpty) containerResumoNovo(),
        ],
      ),
    );
  }

  Widget itemMenu(String nome, String preco, String emoji, String desc) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 30)),
      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 10)),
      trailing: IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange, size: 30), onPressed: () => adicionarAoCarrinho(nome, preco)),
    );
  }

  Widget containerResumoNovo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[300]!, width: 3)), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const SizedBox(width: 48), const Text("CONFERIR PEDIDO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () => setState(() => carrinhoMap.clear()))]),
          ...carrinhoMap.entries.map((entry) => Row(children: [Text("${entry.value['qtd']}x", style: TextStyle(color: corLaranja, fontWeight: FontWeight.bold)), const SizedBox(width: 12), Expanded(child: Text(entry.key)), IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => removerDoCarrinho(entry.key)), IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => adicionarAoCarrinho(entry.key, entry.value['preco']))])).toList(),
          const Divider(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => abrirAbaFinalizacao(),
            child: const Text("PROSSEGUIR PARA PAGAMENTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

// TELA DO MAPA PARA O PIN
class TelaSelecaoMapa extends StatefulWidget {
  const TelaSelecaoMapa({super.key});
  @override
  _TelaSelecaoMapaState createState() => _TelaSelecaoMapaState();
}

class _TelaSelecaoMapaState extends State<TelaSelecaoMapa> {
  LatLng _posicaoAtual = const LatLng(-23.7025, -46.7562); 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Arraste o mapa sob o Pin"), backgroundColor: const Color(0xFF1A1A1A)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _posicaoAtual, zoom: 16),
            onCameraMove: (position) => _posicaoAtual = position.target,
          ),
          const Center(child: Icon(Icons.location_on, size: 50, color: Colors.red)),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
          onPressed: () => Navigator.pop(context, _posicaoAtual),
          child: const Text("CONFIRMAR LOCAL NO PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// PÁGINA DE STATUS
class PaginaStatus extends StatelessWidget {
  final String endereco;
  final double total;
  const PaginaStatus({super.key, required this.endereco, required this.total});

  void abrirSuporteWhatsapp() {
    String mensagem = "Olá! Preciso de ajuda com meu pedido no KamiKami. Endereço: $endereco";
    String url = "https://wa.me/5511999999999?text=${Uri.encodeComponent(mensagem)}";
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Acompanhar Pedido"), backgroundColor: const Color(0xFF1A1A1A), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 70),
            const SizedBox(height: 10),
            const Text("PEDIDO CONFIRMADO!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("Estamos preparando seu Yakissoba.", textAlign: TextAlign.center),
            const SizedBox(height: 30),
            statusRow(Icons.receipt_long, "Pedido Recebido", true),
            statusRow(Icons.restaurant, "Cozinhando", true),
            statusRow(Icons.moped, "Aguardando Entregador", false),
            const Divider(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 55)),
              icon: const Icon(Icons.chat, color: Colors.white),
              label: const Text("SUPORTE WHATSAPP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: abrirSuporteWhatsapp,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF944D), width: 2), minimumSize: const Size(double.infinity, 55)),
              icon: const Icon(Icons.camera_alt, color: Color(0xFFFF944D)),
              label: const Text("INSTAGRAM @KAMIKAMI", style: TextStyle(color: Color(0xFFFF944D), fontWeight: FontWeight.bold)),
              onPressed: () => launchUrl(Uri.parse("https://instagram.com/kamikamiyakissoba")),
            ),
          ],
        ),
      ),
    );
  }

  Widget statusRow(IconData icon, String texto, bool concluido) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: concluido ? Colors.green.withOpacity(0.2) : Colors.grey[200], child: Icon(icon, color: concluido ? Colors.green : Colors.grey, size: 20)),
          const SizedBox(width: 15),
          Text(texto, style: TextStyle(fontWeight: concluido ? FontWeight.bold : FontWeight.normal, color: concluido ? Colors.black : Colors.grey)),
          const Spacer(),
          if (concluido) const Icon(Icons.check_circle, color: Colors.green, size: 20)
        ],
      ),
    );
  }
}