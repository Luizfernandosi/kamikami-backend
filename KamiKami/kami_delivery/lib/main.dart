import 'package:flutter/material.dart';
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
  double taxaFixa = 7.00; // ALTERE AQUI O VALOR DA SUA ENTREGA PRÓPRIA
  TextEditingController enderecoController = TextEditingController();
  bool enderecoValidado = false;
  
  final Color corLaranja = const Color(0xFFFF944D); 
  final Color corPreta = const Color(0xFF1A1A1A);
  final String urlBase = "https://kamikami-backend.onrender.com";

  double get total {
    double subtotal = 0;
    carrinhoMap.forEach((key, value) {
      double preco = double.parse(value['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'));
      subtotal += preco * value['qtd'];
    });
    return subtotal + (enderecoValidado ? frete : 0);
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

  // Validação para Entrega Própria
  void validarEnderecoProprio(String endereco, StateSetter setModalState) {
    if (endereco.length > 10) {
      setState(() => frete = taxaFixa);
      setModalState(() => enderecoValidado = true);
    } else {
      setModalState(() => enderecoValidado = false);
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
                TextField(
                  controller: enderecoController,
                  onChanged: (val) => validarEnderecoProprio(val, setModalState),
                  decoration: InputDecoration(
                    labelText: "Seu Endereço Completo",
                    hintText: "Rua, Número, Bairro",
                    prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                    suffixIcon: Icon(
                      enderecoValidado ? Icons.check_circle : Icons.error_outline,
                      color: enderecoValidado ? Colors.green : Colors.grey,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal:"), Text("R\$ ${(total - (enderecoValidado ? frete : 0)).toStringAsFixed(2)}")]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Taxa de Entrega:"), Text("R\$ ${frete.toStringAsFixed(2)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))]),
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
                const SizedBox(height: 10),
                const Text("Sua entrega será feita por nossa equipe própria.", style: TextStyle(fontSize: 11, color: Colors.grey)),
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
    
    try {
      final response = await http.post(
        Uri.parse('$urlBase/checkout'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "itens": itens, 
          "endereco": enderecoController.text, 
          "frete": frete,
          "entrega_propria": true
        }),
      );
      
      if (response.statusCode == 200) {
        var dados = json.decode(response.body);
        await launchUrl(Uri.parse(dados['qr_code_url']), mode: LaunchMode.externalApplication);
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PaginaStatus(
            endereco: enderecoController.text,
            total: total,
          )),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao processar pedido. Tente novamente.")));
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
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[300]!, width: 3)), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
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

class PaginaStatus extends StatelessWidget {
  final String endereco;
  final double total;
  const PaginaStatus({super.key, required this.endereco, required this.total});

  void abrirSuporteWhatsapp() {
    String mensagem = "Olá! Preciso de ajuda com meu pedido no KamiKami. Endereço: $endereco";
    String url = "https://wa.me/5511999999999?text=${Uri.encodeComponent(mensagem)}"; // COLOQUE SEU NUMERO AQUI
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
            const Text("Seu Yakissoba já entrou em produção!", textAlign: TextAlign.center),
            const SizedBox(height: 30),
            statusRow(Icons.receipt_long, "Pedido Recebido", true),
            statusRow(Icons.restaurant, "Preparando na Cozinha", true),
            statusRow(Icons.moped, "Saiu para entrega (Equipe Própria)", false),
            statusRow(Icons.home, "Entregue", false),
            const Divider(height: 40),
            const Text("DÚVIDAS SOBRE A ENTREGA?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 55)),
              icon: const Icon(Icons.chat, color: Colors.white),
              label: const Text("CHAMAR NO WHATSAPP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: abrirSuporteWhatsapp,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF944D), width: 2), minimumSize: const Size(double.infinity, 55)),
              icon: const Icon(Icons.camera_alt, color: Color(0xFFFF944D)),
              label: const Text("VER NOSSO INSTAGRAM", style: TextStyle(color: Color(0xFFFF944D), fontWeight: FontWeight.bold)),
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
          Expanded(child: Text(texto, style: TextStyle(fontWeight: concluido ? FontWeight.bold : FontWeight.normal, color: concluido ? Colors.black : Colors.grey, fontSize: 15))),
          if (concluido) const Icon(Icons.check_circle, color: Colors.green, size: 20)
        ],
      ),
    );
  }
}