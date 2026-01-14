import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MaterialApp(home: AppCliente(), debugShowCheckedModeBanner: false));

class AppCliente extends StatefulWidget {
  const AppCliente({super.key});
  @override
  State<AppCliente> createState() => _AppClienteState();
}

class _AppClienteState extends State<AppCliente> {
  Map<String, Map<String, dynamic>> carrinhoMap = {};
  double frete = 7.00;
  
  final Color corLaranja = const Color(0xFFFF944D); 
  final Color corPreta = const Color(0xFF1A1A1A);
  
  TextEditingController cepController = TextEditingController();
  TextEditingController ruaController = TextEditingController();
  TextEditingController numeroController = TextEditingController();
  TextEditingController complementoController = TextEditingController();
  TextEditingController bairroController = TextEditingController();
  TextEditingController referenciaController = TextEditingController();
  
  bool carregandoCep = false;
  String mensagemErroCep = "";
  final String urlBase = "https://kamikami-backend.onrender.com";

  double get valorSubtotal {
    double sub = 0;
    carrinhoMap.forEach((key, value) {
      double preco = double.parse(value['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'));
      sub += preco * value['qtd'];
    });
    return sub;
  }

  double get valorTotalFinal => valorSubtotal + frete;

  bool get podeFinalizar => 
    cepController.text.length == 9 && 
    ruaController.text.isNotEmpty && 
    numeroController.text.isNotEmpty && 
    carrinhoMap.isNotEmpty;

  Future<void> buscarCEP(String valor, StateSetter setModalState) async {
    String cepLimpo = valor.replaceAll('-', '');
    if (cepLimpo.length > 5 && !valor.contains('-')) {
      String formatado = "${cepLimpo.substring(0, 5)}-${cepLimpo.substring(5)}";
      cepController.value = TextEditingValue(
        text: formatado,
        selection: TextSelection.collapsed(offset: formatado.length),
      );
    }
    if (cepLimpo.length == 8) {
      setModalState(() { carregandoCep = true; mensagemErroCep = ""; });
      try {
        final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cepLimpo/json/'));
        if (response.statusCode == 200) {
          final dados = json.decode(response.body);
          if (dados['erro'] == null) {
            setModalState(() {
              ruaController.text = dados['logradouro'] ?? "";
              bairroController.text = dados['bairro'] ?? "";
              carregandoCep = false;
            });
          } else {
            setModalState(() { carregandoCep = false; mensagemErroCep = "CEP não encontrado!"; ruaController.clear(); bairroController.clear(); });
          }
        }
      } catch (e) { setModalState(() => carregandoCep = false); }
    } else if (cepLimpo.length < 8) {
      setModalState(() { ruaController.clear(); bairroController.clear(); mensagemErroCep = ""; });
    }
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

  void abrirCheckoutUnificado() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true, // Habilita o arrastar para baixo
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // BARRINHA DE ARRASTAR (INDICADOR VISUAL)
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("REVISÃO E PAGAMENTO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  if (mensagemErroCep.isNotEmpty)
                    Text(mensagemErroCep, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const Divider(),
                  
                  // CEP
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cepController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18),
                          maxLength: 9,
                          decoration: const InputDecoration(labelText: "CEP *", counterText: ""),
                          onChanged: (val) => buscarCEP(val, setModalState),
                        ),
                      ),
                      if (carregandoCep) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
                    ],
                  ),
                  
                  TextField(
                    controller: ruaController, 
                    readOnly: true,
                    style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
                    decoration: const InputDecoration(labelText: "Rua/Avenida", filled: true, fillColor: Color(0xFFF8F8F8)),
                  ),
                  
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        flex: 2, 
                        child: TextField(
                          controller: numeroController, 
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18), 
                          decoration: const InputDecoration(labelText: "Nº *", hintText: "Ex: 123"), 
                          onChanged: (v) => setModalState((){})
                        )
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        flex: 3, 
                        child: TextField(
                          controller: complementoController, 
                          style: const TextStyle(fontSize: 18), 
                          decoration: const InputDecoration(
                            labelText: "Apto/Bloco/Casa", 
                            hintText: "Se houver",
                            labelStyle: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)
                          ),
                        )
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: bairroController, 
                    readOnly: true, 
                    style: const TextStyle(fontSize: 18, color: Colors.blueGrey), 
                    decoration: const InputDecoration(labelText: "Bairro", filled: true, fillColor: Color(0xFFF8F8F8))
                  ),

                  TextField(
                    controller: referenciaController, 
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(labelText: "Ponto de Referência", hintText: "Ex: Próximo ao mercado..."),
                  ),
                  
                  const SizedBox(height: 20),
                  const Text("ITENS DO PEDIDO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  
                  ...carrinhoMap.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Text("${entry.value['qtd']}x", style: TextStyle(color: corLaranja, fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 18))),
                      IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32), onPressed: () { removerDoCarrinho(entry.key); setModalState(() {}); }),
                      IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: () { adicionarAoCarrinho(entry.key, entry.value['preco']); setModalState(() {}); }),
                    ]),
                  )).toList(),
                  
                  const Divider(height: 30),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("TOTAL:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("R\$ ${valorTotalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 28, color: Colors.green, fontWeight: FontWeight.bold))
                  ]),
                  
                  const SizedBox(height: 25),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: podeFinalizar ? Colors.blue : Colors.grey,
                      minimumSize: const Size(double.infinity, 65),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: podeFinalizar ? () => processarPagamento() : null,
                    child: const Text("PAGAR COM MERCADO PAGO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> processarPagamento() async {
    List itens = [];
    carrinhoMap.forEach((k, v) => itens.add({"nome": k, "preco": double.parse(v['preco'].replaceAll('R\$ ', '').replaceAll(',', '.'))}));
    final enderecoFormatado = "${ruaController.text}, ${numeroController.text} (${complementoController.text}). Bairro: ${bairroController.text}. Ref: ${referenciaController.text}. CEP: ${cepController.text}";
    final response = await http.post(
      Uri.parse('$urlBase/checkout'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"itens": itens, "endereco": enderecoFormatado, "frete": frete}),
    );
    if (response.statusCode == 200) {
      var dados = json.decode(response.body);
      await launchUrl(Uri.parse(dados['qr_code_url']), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("KAMI KAMI YAKISSOBA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)), centerTitle: true, backgroundColor: corPreta),
      body: Column(
        children: [
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), color: corLaranja, child: const Text("MENU COMPLETO", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          Expanded(
            child: ListView(
              children: [
                itemMenu('01 - CARNE', 'R\$ 29,90', '🥩', 'Carne+Legumes+Verduras Tradicionais'),
                itemMenu('02 - MISTO', 'R\$ 28,90', '🍱', 'Carne e Frango+Legumes+Verduras'),
                itemMenu('03 - FRANGO', 'R\$ 27,90', '🍗', 'Frango+Legumes+Verduras Tradicionais'),
                itemMenu('04 - LEGUMES', 'R\$ 26,90', '🥦', 'Legumes+Verduras Tradicionais'),
                itemMenu('05 - CAMARÃO', 'R\$ 34,90', '🍤', 'Camarão+Legumes+Verduras Tradicionais'),
                itemMenu('06 - TEMAKI SALMÃO', 'R\$ 30,90', '🍣', 'Salmão Fresco, Cream Cheese e Cebolinha'),
                const Divider(),
                itemMenu('PRODUTO TESTE', 'R\$ 2,00', '🛠️', 'Teste de Pagamento'),
                const SizedBox(height: 40),
                secaoInstagram(),
                const SizedBox(height: 120),
              ],
            ),
          ),
          if (carrinhoMap.isNotEmpty) containerResumoFlutuante(),
        ],
      ),
    );
  }

  Widget itemMenu(String nome, String preco, String emoji, String desc) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 35)),
      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      subtitle: Text("$desc\n$preco", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange, size: 35), onPressed: () => adicionarAoCarrinho(nome, preco)),
    );
  }

  Widget secaoInstagram() {
    return Center(
      child: InkWell(
        onTap: () => launchUrl(Uri.parse("https://instagram.com/kamikamiyakissoba")),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.purple, Colors.pink, Colors.orange]),
                borderRadius: BorderRadius.circular(15)
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 8),
            const Text("SIGA NOSSO INSTAGRAM", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget containerResumoFlutuante() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[300]!, width: 2))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("${carrinhoMap.length} item(ns)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Subtotal: R\$ ${valorSubtotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20))
          ]),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)),
            onPressed: () => abrirCheckoutUnificado(),
            child: const Text("REVISAR E PAGAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          )
        ],
      ),
    );
  }
}