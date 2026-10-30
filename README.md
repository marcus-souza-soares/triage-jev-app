# Triagem

Triagem de chamados de suporte em Rails 8. Cole a mensagem do cliente e o
[Jev](https://docs.typesafe.ai) decide, em menos de um segundo:

- **Departamento**: Financeiro, Suporte técnico ou Comercial
- **Urgência**: sim ou não
- **Gravidade**: trivial, baixa, alta ou crítica

O Jev não gera texto. Ele devolve respostas tipadas com probabilidades e
confiança calibradas. Quando a confiança fica abaixo do mínimo, o chamado é
marcado para revisão humana.

## O que tem aqui

- **Triagem** (`/tickets/new`): formulário com três níveis de rigor (padrão, 90% ou 95% de confiança mínima).
- **Histórico** (`/tickets`): chamados anteriores, paginados, com selo "Revisar" nos incertos.
- **Detalhes da análise** (`/tickets/:id`): distribuição de probabilidades por pergunta, confiança, mínimo exigido, margem, tokens e a requisição exata enviada ao Jev.
- **Benchmark** (`/benchmarks`): o Jev contra uma LLM nos mesmos chamados, comparando tempo, tokens e concordância com um gabarito.
- Interface em português, com Tailwind e tema escuro.

## Stack

- Ruby 4.0.9 e Rails 8.1, com SQLite, Hotwire e Tailwind CSS 4
- [jevalyn](https://github.com/Ray-Hughes/jevalyn), cliente Ruby do Jev, servido pelo [OpenCode Zen](https://opencode.ai) com o modelo `jev-1.13-free`

## Como rodar

```sh
bin/setup --skip-server   # instala as gems e prepara o banco
```

Crie um `.env` na raiz. Ele já está no `.gitignore`.

```sh
OPENCODE_API_KEY=oc_sk_...   # obrigatória: chave do OpenCode Zen
OPENAI_API_KEY=sk-...        # opcional: só para o benchmark com modelos da OpenAI
```

Para conferir a conexão e subir o app:

```sh
bin/rails jevalyn:ping   # confere a chave e a conexão com o Zen
bin/dev                  # servidor + Tailwind em modo watch, em http://localhost:3000
```

> Se o `bin/dev` responder `foreman: not found` e você usa asdf, rode `asdf reshim ruby`.

## Como funciona

A triagem fica em [`app/decisions/support_triage.rb`](app/decisions/support_triage.rb).
São três perguntas, enviadas ao Jev numa única requisição:

```ruby
class SupportTriage < Jevalyn::Decision
  question :urgent,     type: :noul,   ...                               # sim/não
  question :department, type: :choice, ..., confidence_threshold: 0.8    # errar o time custa caro
  question :severity,   type: :score,  ..., confidence_threshold: 0.6
  confidence_threshold 0.75
end
```

`Ticket.triage!(body)` avalia a mensagem e salva as respostas junto com um
retrato completo da análise (coluna JSON `analysis`). Assim, o histórico
continua mostrando o que o Jev respondeu na época, mesmo que as perguntas mudem
depois.

### No console

```ruby
r = SupportTriage.evaluate("Fui cobrado duas vezes na fatura de outubro")
r.department                 # => :billing
r.department_probabilities   # => { "billing" => 0.97, ... }
r.urgent?(0.9)               # corte de urgência mais exigente
r.severity_label             # => "minor"
r.uncertain_questions        # perguntas abaixo do mínimo de confiança
```

Para perguntas avulsas, sem criar uma classe nova, use o `JevClient`:

```ruby
JevClient.decide(state: "Quero cancelar", questions: {
  refund: { type: :noul, instructions: "O cliente pede reembolso?",
            criteria: { true: "Pede dinheiro de volta", false: "Não pede" } }
}).refund?
```

Há mais exemplos em [`lib/scripts/rails_console_examples.rb`](lib/scripts/rails_console_examples.rb).
Dentro do console, rode `load "lib/scripts/rails_console_examples.rb"`.
Esses exemplos fazem chamadas reais ao Jev.

## Benchmark

```sh
bin/rails benchmark:triage                                  # padrão: opencode/glm-5.3-flash-free
LLM=openai/gpt-5 bin/rails benchmark:triage                 # API da OpenAI (gasta créditos)
LLM=openai/gpt-5 REASONING=minimal bin/rails benchmark:triage
```

O benchmark tria 10 chamados com gabarito usando o Jev e a LLM escolhida. As
duas recebem as mesmas perguntas: o prompt da LLM é montado a partir do próprio
`SupportTriage`. O resultado é salvo e aparece em `/benchmarks`.

Os modelos gratuitos do Zen só funcionam pelo `opencode run`. O opencode envia
o próprio prompt de sistema em toda chamada (cerca de 7,4 mil tokens). Para não
distorcer a comparação, o benchmark mede esse custo fixo com uma chamada vazia e
mostra os tokens da LLM brutos e descontados.

Resultado de uma rodada, em média por chamado:

| | Jev | glm-5.3-flash (opencode) | GPT-5 (API) |
|---|---|---|---|
| Tempo | **~725 ms** | ~3,3 s | ~4,2 s |
| Tokens de entrada | 455 | ~180 (sem o custo do opencode) | 182 |
| Tokens de saída | 68 | 86 | 225 (a maior parte é raciocínio) |

São 10 chamados contra um gabarito rotulado à mão, então trate os números como
indicação, não como medida firme.

## Testes

```sh
bin/rails test
```

Os testes não acessam a rede. As respostas do Jev vêm de stubs do
`Jevalyn::Testing`.

## Observações

- **Contorno no `config/application.rb`:** o jevalyn 0.1.0 tenta alterar os
  `autoload_paths` depois que o Rails 8.1 já congelou essa lista, e o app não
  sobe (`FrozenError`). Por isso o `config/application.rb` remove esse
  initializer da gem. Ele é redundante, porque o Rails já carrega `app/decisions`
  sozinho. O contorno pode sair quando a gem registrar o initializer com
  `before: :set_autoload_paths`.
- **Fuso horário:** o app usa `America/Sao_Paulo` (`config.time_zone = "Brasilia"`).
