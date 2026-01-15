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
      '/login_admin': (context) => const TelaLoginAdmin(),
      '/pedidos': (context) => const MonitorPedidos(),
    },
  ));
}

class AppCliente extends StatefulWidget {
  const AppCliente({super.key});
  @override
  State<AppCliente> createState() => _AppClienteState();
}

class _AppClienteState extends State<AppCliente> {
  // CONFIGURAÇÕES VISUAIS ORIGINAIS
  final Color corLaranja = const Color(0xFFFF944D); 
  final Color corPreta = const Color(0xFF1A1A1A);
  final String urlBase = "https://kamikami-backend.onrender.com";

  List produtos = [];
  double frete = 7.00;
  bool carregandoCardapio = true;
  Map<String, Map<String, dynamic>> carrinhoMap = {};
  Map? usuarioLogado;
  double descontoAplicado = 0;
  String cupomAtivo = "";

  // CONTROLLERS DO CHECKOUT
  TextEditingController cepController = TextEditingController();
  TextEditingController ruaController = TextEditingController();
  TextEditingController numeroController = TextEditingController();
  TextEditingController complementoController = TextEditingController();
  TextEditingController bairroController = TextEditingController();
  TextEditingController observacaoController = TextEditingController();
  TextEditingController cupomController = TextEditingController();

  @override
  void initState() { super.initState(); buscarCardapio(); }

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

  Future<void> buscarCEP(String valor, StateSetter setModalState) async {
    if (valor.length == 8) {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$valor/json/'));
      final dados = json.decode(response.body);
      if (dados['erro'] == null) {
        setModalState(() {
          ruaController.text = dados['logradouro'] ?? "";
          bairroController.text = dados['bairro'] ?? "";
        });
      }
    }
  }

  double get valorSubtotal => carrinhoMap.values.fold(0, (sum, item) => sum + (item['preco_num'] * item['qtd']));
  double get valorTotalFinal => (valorSubtotal - descontoAplicado) + frete;

  // ÁREA DE REVISAR E PAGAR (LAYOUT ORIGINAL RESTAURADO)
  void abrirCheckout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Text("REVISAR E PAGAR", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(),
                ...carrinhoMap.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Text("${e.value['qtd']}x", style: TextStyle(color: corLaranja, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 16))),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28), onPressed: () {
                        setState(() { if (carrinhoMap[e.key]!['qtd'] > 1) { carrinhoMap[e.key]!['qtd']--; } else { carrinhoMap.remove(e.key); } });
                        setModalState(() {});
                        if (carrinhoMap.isEmpty) Navigator.pop(ctx);
                      }),
                      IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 28), onPressed: () {
                        setState(() { carrinhoMap[e.key]!['qtd']++; });
                        setModalState(() {});
                      }),
                    ]),
                  ]),
                )),
                const Divider(),
                TextField(controller: cepController, decoration: const InputDecoration(labelText: "CEP *"), keyboardType: TextInputType.number, onChanged: (v) => buscarCEP(v, setModalState)),
                TextField(controller: ruaController, readOnly: true, decoration: const InputDecoration(labelText: "Rua", filled: true, fillColor: Color(0xFFF5F5F5))),
                Row(children: [
                  Expanded(child: TextField(controller: numeroController, decoration: const InputDecoration(labelText: "Nº *"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: complementoController, decoration: const InputDecoration(labelText: "Apto/Casa"))),
                ]),
                TextField(controller: bairroController, readOnly: true, decoration: const InputDecoration(labelText: "Bairro", filled: true, fillColor: Color(0xFFF5F5F5))),
                TextField(controller: observacaoController, decoration: const InputDecoration(labelText: "Ponto de Referência / Obs")),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: cupomController, decoration: const InputDecoration(hintText: "CUPOM"))),
                  TextButton(onPressed: () async {
                    final res = await http.post(Uri.parse('$urlBase/validar_cupom'), headers: {"Content-Type": "application/json"}, body: json.encode({"codigo": cupomController.text}));
                    final d = json.decode(res.body);
                    if (d['status'] == 'valido') {
                      setState(() { 
                        cupomAtivo = cupomController.text.toUpperCase();
                        descontoAplicado = d['tipo'] == 'porcentagem' ? valorSubtotal * (d['valor']/100) : d['valor'].toDouble(); 
                      });
                      setModalState(() {});
                    }
                  }, child: const Text("Aplicar"))
                ]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal:"), Text("R\$ ${valorSubtotal.toStringAsFixed(2)}")]),
                if (descontoAplicado > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Desconto ($cupomAtivo):"), Text("- R\$ ${descontoAplicado.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Taxa de Entrega:"), Text("R\$ ${frete.toStringAsFixed(2)}", style: TextStyle(color: corLaranja, fontWeight: FontWeight.bold))]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("R\$ ${valorTotalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green))]),
                const SizedBox(height: 15),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 60)), onPressed: () => processarPagamento(), child: const Text("FINALIZAR PAGAMENTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> processarPagamento() async {
    List itens = [];
    carrinhoMap.forEach((k, v) => itens.add({"nome": k, "preco": v['preco_num'], "qtd": v['qtd']}));
    final res = await http.post(Uri.parse('$urlBase/checkout'), headers: {"Content-Type": "application/json"}, 
      body: json.encode({"itens": itens, "endereco": "${ruaController.text}, ${numeroController.text}. Obs: ${observacaoController.text}", "frete": frete, "email": usuarioLogado?['email'] ?? "Visitante"}));
    if (res.statusCode == 200) { await launchUrl(Uri.parse(json.decode(res.body)['qr_code_url']), mode: LaunchMode.externalApplication); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: corPreta,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(behavior: HitTestBehavior.opaque, onDoubleTap: () => Navigator.pushNamed(context, '/login_admin'), child: const Text("KAMI KAMI ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            GestureDetector(behavior: HitTestBehavior.opaque, onDoubleTap: () => Navigator.pushNamed(context, '/pedidos'), child: const Text("YAKISSOBA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.person, color: Colors.white), onPressed: () => mostrarLogin())],
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
    double pr = preco.toDouble();
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 35)),
      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("$desc\nR\$ ${pr.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      trailing: IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange, size: 35), onPressed: () {
        setState(() {
          if (carrinhoMap.containsKey(nome)) { carrinhoMap[nome]!['qtd']++; }
          else { carrinhoMap[nome] = {'preco_num': pr, 'qtd': 1}; }
        });
      }),
    );
  }

  Widget secaoInstagram() {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: InkWell(onTap: () => launchUrl(Uri.parse("https://instagram.com/kamikamiyakissoba")), child: Column(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.purple, Colors.pink, Colors.orange]), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.camera_alt, color: Colors.white, size: 30)),
      const Text("SIGA NOSSO INSTAGRAM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
    ]))));
  }

  Widget containerResumoFlutuante() {
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[300]!, width: 2))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${carrinhoMap.length} item(ns)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("R\$ ${valorTotalFinal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20))]),
      const SizedBox(height: 12),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)), onPressed: abrirCheckout, child: const Text("REVISAR E PAGAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
    ]));
  }

  void mostrarLogin() {
    TextEditingController emailC = TextEditingController();
    TextEditingController nomeC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("LOGIN KAMIKAMI"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: emailC, decoration: const InputDecoration(labelText: "E-mail"), onChanged: (v) async {
            if(v.contains("@")) {
               final res = await http.post(Uri.parse('$urlBase/buscar_usuario'), headers: {"Content-Type": "application/json"}, body: json.encode({"email": v}));
               if(res.statusCode == 200) {
                  final d = json.decode(res.body);
                  if(d['status'] == 'encontrado') { nomeC.text = d['nome']; }
               }
            }
        }),
        TextField(controller: nomeC, decoration: const InputDecoration(labelText: "Nome")),
      ]),
      actions: [ElevatedButton(onPressed: () async {
        final d = {"nome": nomeC.text, "email": emailC.text};
        await http.post(Uri.parse('$urlBase/registrar_usuario'), headers: {"Content-Type": "application/json"}, body: json.encode(d));
        setState(() { usuarioLogado = d; });
        Navigator.pop(ctx);
      }, child: const Text("ENTRAR"))],
    ));
  }
}

// --- TELAS DE SUPORTE (ADMIN E MONITOR) ---
class TelaLoginAdmin extends StatelessWidget {
  const TelaLoginAdmin({super.key});
  @override Widget build(BuildContext context) {
    TextEditingController sC = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text("Login Admin"), backgroundColor: Colors.black),
      body: Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextField(controller: sC, obscureText: true, decoration: const InputDecoration(labelText: "Senha")),
        ElevatedButton(onPressed: () async {
          if (sC.text == "Kami-MAS") {
            final res = await http.get(Uri.parse('https://kamikami-backend.onrender.com/cardapio'));
            if (context.mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (ctx) => PainelAdmin(urlBase: 'https://kamikami-backend.onrender.com', configInicial: json.decode(res.body))));
            }
          }
        }, child: const Text("Entrar"))
      ]))),
    );
  }
}

class PainelAdmin extends StatefulWidget {
  final String urlBase; final Map configInicial;
  const PainelAdmin({super.key, required this.urlBase, required this.configInicial});
  @override State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> {
  late TextEditingController fC; late List pE; List cl = [], cp = [];
  @override void initState() { 
    super.initState(); 
    fC = TextEditingController(text: widget.configInicial['frete'].toString());
    pE = List.from(widget.configInicial['produtos']);
    carregarDados();
  }
  carregarDados() async {
    final rC = await http.get(Uri.parse('${widget.urlBase}/admin/clientes'));
    final rQ = await http.get(Uri.parse('${widget.urlBase}/admin/cupons'));
    if (mounted) setState(() { cl = json.decode(rC.body); cp = json.decode(rQ.body); });
  }
  @override Widget build(BuildContext context) {
    return DefaultTabController(length: 3, child: Scaffold(
      appBar: AppBar(title: const Text("ADMIN"), backgroundColor: Colors.red, bottom: const TabBar(tabs: [Tab(text: "Menu"), Tab(text: "Cupons"), Tab(text: "Clientes")])),
      body: TabBarView(children: [
        Column(children: [
          Expanded(child: ListView.builder(itemCount: pE.length, itemBuilder: (ctx, i) => ListTile(title: Text(pE[i]['nome']), trailing: Switch(value: pE[i]['ativo'], onChanged: (v) => setState(() => pE[i]['ativo'] = v))))),
          ElevatedButton(onPressed: () async { await http.post(Uri.parse('${widget.urlBase}/atualizar_cardapio'), headers: {"Content-Type": "application/json"}, body: json.encode({"senha": "Kami-MAS", "config": {"frete": double.parse(fC.text), "produtos": pE}})); }, child: const Text("SALVAR")),
        ]),
        ListView.builder(itemCount: cp.length, itemBuilder: (ctx, i) => ListTile(title: Text(cp[i]['codigo']), subtitle: Text("${cp[i]['valor']} ${cp[i]['tipo']}"))),
        ListView.builder(itemCount: cl.length, itemBuilder: (ctx, i) => ListTile(title: Text(cl[i]['nome']), subtitle: Text(cl[i]['email']))),
      ]),
    ));
  }
}

class MonitorPedidos extends StatefulWidget {
  const MonitorPedidos({super.key});
  @override State<MonitorPedidos> createState() => _MonitorPedidosState();
}

class _MonitorPedidosState extends State<MonitorPedidos> {
  List peds = []; Timer? t;
  @override void initState() { super.initState(); buscar(); t = Timer.periodic(const Duration(seconds: 20), (t) => buscar()); }
  @override void dispose() { t?.cancel(); super.dispose(); }
  Future<void> buscar() async { 
    final res = await http.get(Uri.parse('https://kamikami-backend.onrender.com/listar_pedidos')); 
    if (res.statusCode == 200 && mounted) setState(() { peds = json.decode(res.body); }); 
  }
  @override Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(title: const Text("PEDIDOS"), backgroundColor: Colors.green), 
      body: ListView.builder(itemCount: peds.length, itemBuilder: (ctx, i) => Card(child: ListTile(title: Text("Pedido #${peds[i]['id']}"), subtitle: Text("${peds[i]['endereco']}\nTotal: R\$ ${peds[i]['total']}")))),
    ); 
  }
}