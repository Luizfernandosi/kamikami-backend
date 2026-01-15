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

// --- TELA PRINCIPAL ---
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
  
  // LOGIN E DESCONTO
  Map? usuarioLogado;
  double descontoAplicado = 0;
  String cupomAtivo = "";

  final Color corLaranja = const Color(0xFFFF944D); 
  final Color corPreta = const Color(0xFF1A1A1A);
  
  TextEditingController cepController = TextEditingController();
  TextEditingController ruaController = TextEditingController();
  TextEditingController numeroController = TextEditingController();
  TextEditingController complementoController = TextEditingController();
  TextEditingController bairroController = TextEditingController();
  TextEditingController cupomController = TextEditingController();
  
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

  double get valorTotalFinal => (valorSubtotal - descontoAplicado) + frete;

  // FUNÇÃO PARA VALIDAR CUPOM
  Future<void> aplicarCupom() async {
    final res = await http.post(
      Uri.parse('$urlBase/validar_cupom'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"codigo": cupomController.text})
    );
    if (res.statusCode == 200) {
      final dados = json.decode(res.body);
      if (dados['status'] == 'valido') {
        setState(() {
          cupomAtivo = cupomController.text.toUpperCase();
          if (dados['tipo'] == 'porcentagem') {
            descontoAplicado = valorSubtotal * (dados['valor'] / 100);
          } else {
            descontoAplicado = dados['valor'].toDouble();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cupom aplicado!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cupom inválido"), backgroundColor: Colors.red));
      }
    }
  }

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
                const Text("FINALIZAR PEDIDO", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(),
                TextField(controller: cepController, decoration: const InputDecoration(labelText: "CEP *")),
                TextField(controller: ruaController, decoration: const InputDecoration(labelText: "Rua *")),
                Row(children: [
                  Expanded(child: TextField(controller: numeroController, decoration: const InputDecoration(labelText: "Nº *"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: complementoController, decoration: const InputDecoration(labelText: "Complemento"))),
                ]),
                const SizedBox(height: 15),
                // ÁREA DE CUPOM
                Row(children: [
                  Expanded(child: TextField(controller: cupomController, decoration: const InputDecoration(hintText: "CUPOM DE DESCONTO"))),
                  ElevatedButton(onPressed: () async {
                    await aplicarCupom();
                    setModalState(() {});
                  }, child: const Text("Aplicar"))
                ]),
                const Divider(height: 30),
                // RESUMO DE VALORES
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal:"), Text("R\$ ${valorSubtotal.toStringAsFixed(2)}")]),
                if (descontoAplicado > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Desconto:"), Text("- R\$ ${descontoAplicado.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Frete:"), Text("R\$ ${frete.toStringAsFixed(2)}", style: const TextStyle(color: Colors.orange))]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("R\$ ${valorTotalFinal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green))]),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 60)),
                  onPressed: () => processarPagamento(),
                  child: const Text("PAGAR COM MERCADO PAGO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> processarPagamento() async {
    List itens = [];
    carrinhoMap.forEach((k, v) => itens.add({"nome": k, "preco": v['preco_num']}));
    final endereco = "${ruaController.text}, ${numeroController.text}. Bairro: ${bairroController.text}";
    final res = await http.post(Uri.parse('$urlBase/checkout'), headers: {"Content-Type": "application/json"}, 
      body: json.encode({"itens": itens, "endereco": endereco, "frete": frete, "email": usuarioLogado?['email'] ?? "Visitante"}));
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
        centerTitle: true, backgroundColor: corPreta,
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

  // TELA SIMPLIFICADA DE LOGIN/CADASTRO
  void mostrarLogin() {
    TextEditingController emailC = TextEditingController();
    TextEditingController nomeC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("CLUBE KAMI KAMI"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("Cadastre-se para receber descontos!"),
        TextField(controller: nomeC, decoration: const InputDecoration(labelText: "Nome")),
        TextField(controller: emailC, decoration: const InputDecoration(labelText: "E-mail")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () async {
          final dados = {"nome": nomeC.text, "email": emailC.text, "endereco": ruaController.text};
          await http.post(Uri.parse('$urlBase/registrar_usuario'), headers: {"Content-Type": "application/json"}, body: json.encode(dados));
          setState(() => usuarioLogado = dados);
          Navigator.pop(ctx);
        }, child: const Text("Cadastrar"))
      ],
    ));
  }

  Widget itemMenu(String nome, dynamic preco, String emoji, String desc) {
    double precoNum = preco.toDouble();
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 35)),
      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          Text("Total: R\$ ${valorTotalFinal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20))
        ]),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)),
          onPressed: abrirCheckout,
          child: const Text("REVISAR E PAGAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        )
      ]),
    );
  }
}

// --- PAINEL ADMIN COM ABAS ---
class PainelAdmin extends StatefulWidget {
  final String urlBase; final Map configInicial;
  const PainelAdmin({super.key, required this.urlBase, required this.configInicial});
  @override State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> {
  late TextEditingController freteController;
  late List prodsEd;
  List clientes = [];
  List cupons = [];

  @override void initState() { 
    super.initState(); 
    freteController = TextEditingController(text: widget.configInicial['frete'].toString());
    prodsEd = List.from(widget.configInicial['produtos']); 
    carregarAdminDados();
  }

  Future<void> carregarAdminDados() async {
    final resC = await http.get(Uri.parse('${widget.urlBase}/admin/clientes'));
    final resQ = await http.get(Uri.parse('${widget.urlBase}/admin/cupons'));
    setState(() {
      clientes = json.decode(resC.body);
      cupons = json.decode(resQ.body);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("GERENCIAR KAMI KAMI"),
          backgroundColor: Colors.red,
          bottom: const TabBar(tabs: [Tab(text: "Cardápio"), Tab(text: "Cupons"), Tab(text: "Clientes")]),
        ),
        body: TabBarView(children: [
          // ABA CARDÁPIO
          Column(children: [
            TextField(controller: freteController, decoration: const InputDecoration(labelText: "Frete (R\$)"), textAlign: TextAlign.center),
            Expanded(child: ListView.builder(itemCount: prodsEd.length, itemBuilder: (ctx, i) => ListTile(title: Text(prodsEd[i]['nome']), trailing: Switch(value: prodsEd[i]['ativo'], onChanged: (v) => setState(() => prodsEd[i]['ativo'] = v))))),
            ElevatedButton(onPressed: () async {
              await http.post(Uri.parse('${widget.urlBase}/atualizar_cardapio'), headers: {"Content-Type": "application/json"}, body: json.encode({"senha": "Kami-MAS", "config": {"frete": double.parse(freteController.text), "produtos": prodsEd}}));
            }, child: const Text("SALVAR CARDÁPIO"))
          ]),
          // ABA CUPONS
          ListView.builder(itemCount: cupons.length, itemBuilder: (ctx, i) => ListTile(title: Text(cupons[i]['codigo']), subtitle: Text("Desconto: ${cupons[i]['valor']} ${cupons[i]['tipo'] == 'fixo' ? 'Reais' : '%'}"))),
          // ABA CLIENTES
          ListView.builder(itemCount: clientes.length, itemBuilder: (ctx, i) => ListTile(title: Text(clientes[i]['nome']), subtitle: Text(clientes[i]['email'])))
        ]),
      ),
    );
  }
}

// Reutilize as classes MonitorPedidos e TelaLoginAdmin (Login de Senha) do código anterior
// ... [Mantenha MonitorPedidos e TelaLoginAdmin idênticos ao anterior]