import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    initialRoute: '/',
    routes: {
      '/': (context) => const AppCliente(),
      '/admin': (context) => const TelaLoginAdmin(),
      '/pedidos': (context) => const MonitorPedidos(),
    },
  ));
}

// --- TELA DO CLIENTE (LAYOUT ORIGINAL PRESERVADO) ---
class AppCliente extends StatefulWidget {
  const AppCliente({super.key});
  @override
  State<AppCliente> createState() => _AppClienteState();
}

class _AppClienteState extends State<AppCliente> {
  List produtos = [];
  double frete = 7.00;
  bool carregandoCardapio = true;
  Map<String, Map<String, dynamic>> carrinhoMap = {};

  final Color corLaranja = const Color(0xFFFF944D); 
  final Color corPreta = const Color(0xFF1A1A1A);
  
  TextEditingController cepController = TextEditingController();
  TextEditingController ruaController = TextEditingController();
  TextEditingController numeroController = TextEditingController();
  TextEditingController complementoController = TextEditingController();
  TextEditingController bairroController = TextEditingController();
  TextEditingController referenciaController = TextEditingController();
  
  final String urlBase = "https://kamikami-backend.onrender.com";

  @override
  void initState() {
    super.initState();
    buscarCardapio();
  }

  Future<void> buscarCardapio() async {
    try {
      final res = await http.get(Uri.parse('$urlBase/cardapio'));
      if (res.statusCode == 200) {
        final dados = json.decode(res.body);
        setState(() {
          produtos = dados['produtos'];
          frete = dados['frete'].toDouble();
          carregandoCardapio = false;
        });
      }
    } catch (e) { debugPrint("Erro: $e"); }
  }

  double get valorSubtotal {
    double sub = 0;
    carrinhoMap.forEach((key, value) => sub += value['preco_num'] * value['qtd']);
    return sub;
  }

  double get valorTotalFinal => valorSubtotal + frete;

  bool get podeFinalizar => 
    cepController.text.length == 9 && ruaController.text.isNotEmpty && 
    numeroController.text.isNotEmpty && carrinhoMap.isNotEmpty;

  void abrirCheckoutUnificado() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const Text("DADOS DE ENTREGA", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Divider(),
                  TextField(controller: cepController, decoration: const InputDecoration(labelText: "CEP *"), keyboardType: TextInputType.number),
                  TextField(controller: ruaController, decoration: const InputDecoration(labelText: "Rua *")),
                  Row(children: [
                    Expanded(flex: 2, child: TextField(controller: numeroController, decoration: const InputDecoration(labelText: "Nº *"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: TextField(controller: complementoController, decoration: const InputDecoration(labelText: "Complemento"))),
                  ]),
                  TextField(controller: bairroController, decoration: const InputDecoration(labelText: "Bairro")),
                  TextField(controller: referenciaController, decoration: const InputDecoration(labelText: "Ponto de Referência")),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal:"), Text("R\$ ${valorSubtotal.toStringAsFixed(2)}")]),
                        const SizedBox(height: 5),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Frete:"), Text("R\$ ${frete.toStringAsFixed(2)}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]),
                        const Divider(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("R\$ ${valorTotalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green))]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 60)),
                    onPressed: () => processarPagamento(),
                    child: const Text("PAGAR COM MERCADO PAGO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    carrinhoMap.forEach((k, v) => itens.add({"nome": k, "preco": v['preco_num']}));
    final endereco = "${ruaController.text}, ${numeroController.text}. Bairro: ${bairroController.text}. Ref: ${referenciaController.text}";
    final res = await http.post(Uri.parse('$urlBase/checkout'), headers: {"Content-Type": "application/json"}, body: json.encode({"itens": itens, "endereco": endereco, "frete": frete}));
    if (res.statusCode == 200) {
      final url = json.decode(res.body)['qr_code_url'];
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(onDoubleTap: () => Navigator.pushNamed(context, '/admin'), child: const Text("KAMI KAMI YAKISSOBA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        centerTitle: true, backgroundColor: corPreta
      ),
      body: carregandoCardapio ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), color: corLaranja, child: const Text("MENU COMPLETO", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(child: ListView(children: [
            ...produtos.where((p) => p['ativo']).map((p) => itemMenu(p['nome'], p['preco'], p['emoji'], p['desc'])),
            secaoInstagram(),
          ])),
          if (carrinhoMap.isNotEmpty) containerResumoFlutuante(),
        ],
      ),
    );
  }

  Widget itemMenu(String nome, dynamic preco, String emoji, String desc) {
    double precoNum = preco.toDouble();
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 35)),
      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      subtitle: Text("$desc\nR\$ ${precoNum.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      trailing: IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange, size: 35), onPressed: () {
        setState(() {
          if (carrinhoMap.containsKey(nome)) { carrinhoMap[nome]!['qtd']++; }
          else { carrinhoMap[nome] = {'preco_num': precoNum, 'qtd': 1}; }
        });
      }),
    );
  }

  Widget secaoInstagram() {
    return Center(
      child: InkWell(
        onTap: () => launchUrl(Uri.parse("https://instagram.com/kamikamiyakissoba")),
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.purple, Colors.pink, Colors.orange]), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.camera_alt, color: Colors.white, size: 30)),
            const SizedBox(height: 8),
            const Text("SIGA NOSSO INSTAGRAM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          ]),
        ),
      ),
    );
  }

  Widget containerResumoFlutuante() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[300]!, width: 2))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("${carrinhoMap.length} item(ns)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text("Subtotal: R\$ ${valorSubtotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20))
        ]),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)),
          onPressed: abrirCheckoutUnificado,
          child: const Text("REVISAR E PAGAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        )
      ]),
    );
  }
}

// --- MONITOR DE PEDIDOS (NOVA JANELA) ---
class MonitorPedidos extends StatefulWidget {
  const MonitorPedidos({super.key});
  @override
  State<MonitorPedidos> createState() => _MonitorPedidosState();
}

class _MonitorPedidosState extends State<MonitorPedidos> {
  List pedidos = [];
  Timer? timer;
  final String urlBase = "https://kamikami-backend.onrender.com";

  @override
  void initState() {
    super.initState();
    buscarPedidos();
    // Atualiza a tela a cada 30 segundos automaticamente
    timer = Timer.periodic(const Duration(seconds: 30), (t) => buscarPedidos());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> buscarPedidos() async {
    try {
      final res = await http.get(Uri.parse('$urlBase/listar_pedidos'));
      if (res.statusCode == 200) {
        setState(() { pedidos = json.decode(res.body); });
      }
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(title: const Text("PAINEL DE PEDIDOS - COZINHA"), backgroundColor: Colors.black, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: buscarPedidos)]),
      body: pedidos.isEmpty 
        ? const Center(child: Text("Nenhum pedido recebido ainda...", style: TextStyle(fontSize: 18)))
        : ListView.builder(
            itemCount: pedidos.length,
            itemBuilder: (ctx, i) {
              final p = pedidos[i];
              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("PEDIDO #${p['id']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        Text(p['hora'], style: const TextStyle(color: Colors.blue)),
                      ]),
                      const Divider(),
                      ...p['itens'].map<Widget>((item) => Text("• ${item['nome']}", style: const TextStyle(fontSize: 16))).toList(),
                      const Divider(),
                      Text("ENTREGAR EM:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      Text(p['endereco']),
                      const SizedBox(height: 10),
                      Text("TOTAL: R\$ ${p['total'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

// --- TELA DE LOGIN ADMIN ---
class TelaLoginAdmin extends StatelessWidget {
  const TelaLoginAdmin({super.key});
  @override
  Widget build(BuildContext context) {
    TextEditingController senhaCtrl = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text("Acesso Restrito"), backgroundColor: Colors.black),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextField(controller: senhaCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Senha", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            if (senhaCtrl.text == "Kami-MAS") {
              final res = await http.get(Uri.parse('https://kamikami-backend.onrender.com/cardapio'));
              final dados = json.decode(res.body);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (ctx) => PainelAdmin(urlBase: 'https://kamikami-backend.onrender.com', configInicial: dados)));
            }
          }, child: const Text("Entrar")),
        ]),
      )),
    );
  }
}

// --- PAINEL ADMIN (LIXEIRA, DESFAZER E ADICIONAR ITEM) ---
class PainelAdmin extends StatefulWidget {
  final String urlBase; final Map configInicial;
  const PainelAdmin({super.key, required this.urlBase, required this.configInicial});
  @override State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> {
  late TextEditingController freteController;
  late List prodsEd;
  bool salvando = false;

  @override void initState() { 
    super.initState(); 
    freteController = TextEditingController(text: widget.configInicial['frete'].toString());
    prodsEd = List.from(widget.configInicial['produtos']); 
  }

  void adicionarNovoItem() {
    TextEditingController nC = TextEditingController(), pC = TextEditingController(), dC = TextEditingController(), eC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Novo Item"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: "Nome")),
        TextField(controller: pC, decoration: const InputDecoration(labelText: "Preço"), keyboardType: TextInputType.number),
        TextField(controller: dC, decoration: const InputDecoration(labelText: "Descrição")),
        TextField(controller: eC, decoration: const InputDecoration(labelText: "Emoji")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () {
          setState(() => prodsEd.add({"nome": nC.text, "preco": double.tryParse(pC.text) ?? 0.0, "desc": dC.text, "emoji": eC.text.isEmpty ? "🍱" : eC.text, "ativo": true}));
          Navigator.pop(ctx);
        }, child: const Text("Adicionar"))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciar Loja"), backgroundColor: Colors.red),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(children: [
              const Expanded(child: Text("Taxa de Frete (R\$):", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              SizedBox(width: 80, child: TextField(controller: freteController, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
            ]),
          ),
          const Divider(),
          // BOTÃO ADICIONAR AZUL E VISÍVEL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(onPressed: adicionarNovoItem, icon: const Icon(Icons.add, color: Colors.white), label: const Text("NOVO ITEM", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 50))),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: prodsEd.length,
              itemBuilder: (ctx, i) => ListTile(
                leading: Text(prodsEd[i]['emoji'], style: const TextStyle(fontSize: 25)),
                title: Text(prodsEd[i]['nome']),
                subtitle: Text("R\$ ${prodsEd[i]['preco']}"),
                trailing: SizedBox(width: 130, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Switch(value: prodsEd[i]['ativo'], onChanged: (v) => setState(() => prodsEd[i]['ativo'] = v)),
                  IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red, size: 28), onPressed: () {
                    var itemRemovido = prodsEd[i];
                    setState(() { prodsEd.removeAt(i); });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Removido"), action: SnackBarAction(label: "DESFAZER", onPressed: () => setState(() => prodsEd.insert(i, itemRemovido)))));
                  }),
                ])),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)),
              onPressed: () async {
                setState(() => salvando = true);
                await http.post(Uri.parse('${widget.urlBase}/atualizar_cardapio'), headers: {"Content-Type": "application/json"}, body: json.encode({"senha": "Kami-MAS", "config": {"frete": double.parse(freteController.text), "produtos": prodsEd}}));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Salvo!"), backgroundColor: Colors.green));
                setState(() => salvando = false);
              },
              child: salvando ? const CircularProgressIndicator(color: Colors.white) : const Text("SALVAR ALTERAÇÕES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}