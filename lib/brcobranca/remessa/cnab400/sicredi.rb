# -*- encoding: utf-8 -*-
#
module Brcobranca
  module Remessa
    module Cnab400
      class Sicredi < Brcobranca::Remessa::Cnab400::Base
        # convenio do cedente
        attr_accessor :convenio

        attr_accessor :modalidade_carteira
        # identificacao da emissao do boleto (attr na classe base)
        #   opcoes:
        #     ‘1’ = Banco Emite
        #     ‘2’ = Cliente Emite

        attr_accessor :distribuicao_boleto
        #
        # identificacao da distribuicao do boleto (attr na classe base)
        #   opcoes:
        #     ‘1’ = Banco distribui
        #     ‘2’ = Cliente distribui

        attr_accessor :tipo_formulario
        #       Tipo Formulário - 01 posição  (15 a 15):
        #            "1" -auto-copiativo
        #            "3" -auto-envelopável
        #            "4" -A4 sem envelopamento
        #            "6" -A4 sem envelopamento 3 vias

        # convenio do cedente
        attr_accessor :convenio

        validates_presence_of :agencia, :conta_corrente, :carteira, :convenio, :modalidade_carteira, :tipo_formulario, :digito_conta, :sequencial_remessa, :documento_cedente, message: 'não pode estar em branco.'
        # Remessa 400 - 8 digitos
        # Remessa 240 - 12 digitos
        validates_length_of :conta_corrente, is: 3, message: 'deve ter 3 dígitos.'
        validates_length_of :agencia, is: 4, message: 'deve ter 4 dígitos.'
        validates_length_of :modalidade_carteira, is: 1, message: 'deve ter 1 dígitos.'
        validates_length_of :digito_conta, maximum: 1, message: 'deve ter 1 dígito.'
        validates_length_of :sequencial_remessa, maximum: 7, message: 'deve ter 7 dígitos.'
        validates_length_of :carteira, is: 2, message: 'deve ter 2 dígitos.'
        validates_length_of :documento_cedente, minimum: 11, maximum: 14, message: 'deve ter entre 11 e 14 dígitos.'

        # Com DV
        validates_length_of :convenio, is: 5, message: 'deve ter 5 dígitos.'

        def initialize(campos = {})
          campos = {
            distribuicao_boleto: '2',
            tipo_formulario: '4',
            modalidade_carteira: '2',
            sequencial_remessa: '0000001',
            carteira: '01'
          }.merge!(campos)
          super(campos)
        end

        def cod_banco
          '748'
        end

        def nome_banco
          'SICREDI'.ljust(15,' ')
        end

        def data_geracao
          Date.current.strftime('%Y%m%d')
        end

        def endereco_completo(pagamento)
          "#{pagamento.endereco_sacado}, #{pagamento.bairro_sacado}, #{pagamento.cidade_sacado}, #{pagamento.uf_sacado}"
        end

        # Informacoes do Código de Transmissão
        #
        # @return [String]
        #
        def info_conta
          "#{convenio}#{documento_cedente}"
        end

        def digito_agencia
          # utilizando a agencia com 4 digitos
          # para calcular o digito
          agencia.modulo11(mapeamento: { 10 => 'X' }).to_s
        end

        # Complemento do header
        #
        # @return [String]
        #
        def complemento
          '2.00'.rjust(277, ' ')
        end

        # Header do arquivo remessa
        #
        # @return [String]
        #
        def monta_header
          "01REMESSA01COBRANCA       #{info_conta}#{''.rjust(31, ' ')}#{cod_banco}#{nome_banco}#{data_geracao}#{''.rjust(8, ' ')}#{sequencial_remessa.to_s.rjust(7, '0')}#{complemento}000001"
        end

        # Detalhe do arquivo
        #
        # @param pagamento [PagamentoCnab400]
        #   objeto contendo as informacoes referentes ao boleto (valor, vencimento, cliente)
        # @param sequencial
        #   num. sequencial do registro no arquivo
        #
        # @return [String]
        #
        def monta_detalhe(pagamento, sequencial)
          raise Brcobranca::RemessaInvalida, pagamento if pagamento.invalid?

          detalhe = '1AAB            AAA                            '
          detalhe << pagamento.nosso_numero.to_s.gsub('/','').gsub('-','').rjust(9, '0')
          detalhe << ''.rjust(6, ' ')
          detalhe << data_geracao
          detalhe << ' N B0101    00000000000000            '
          detalhe << pagamento.identificacao_ocorrencia                     # identificacao ocorrencia              9[02]
          detalhe << pagamento.numero_documento.to_s.rjust(10, '0')         # numero do documento                   X[10]
          detalhe << pagamento.data_vencimento.strftime('%d%m%y')           # data do vencimento                    9[06]
          detalhe << pagamento.formata_valor                                # valor do documento                    9[13]
          detalhe << ''.rjust(9, ' ')
          detalhe << 'AN'
          detalhe << pagamento.data_emissao.strftime('%d%m%y')              # data de emissao                       9[06]
          detalhe << '00000000000000000'
          detalhe << pagamento.data_vencimento.strftime('%d%m%y')           # data do vencimento                    9[06]
          detalhe << '00000000000000000000000000000000000000'
          detalhe << pagamento.identificacao_sacado.rjust(2, '0')           # identificacao do pagador              9[02]
          detalhe << '0'
          detalhe << pagamento.documento_sacado.to_s.rjust(14, '0')         # documento do pagador                  9[14]
          detalhe << pagamento.nome_sacado.format_size(40).ljust(40, ' ')   # nome do pagador                       X[40]
          detalhe << endereco_completo(pagamento).format_size(40).ljust(40, ' ') # endereco do pagador              X[40]
          detalhe << '00000000000 '
          detalhe << pagamento.cep_sacado                                   # cep do pagador                        9[08]
          detalhe << '00000'
          detalhe << ' '*55                                                 #avalista
          detalhe << sequencial.to_s.rjust(6, '0')                          # numero do registro no arquivo         9[06]
          detalhe


#
#          detalhe << agencia                                                # Prefixo da Cooperativa                9[4]
#          detalhe << digito_agencia                                         # Digito da Cooperativa                 9[1]
#          detalhe << conta_corrente                                         # Conta corrente                        9[8]
#          detalhe << digito_conta                                           # Digito da conta corrente              9[1]
#          detalhe << '000000'                                               # Convênio de Cobrança do Beneficiário: "000000"      9[6]
#          detalhe << pagamento.parcela.to_s.rjust(2, '0')                   # Número da Parcela: "01" se parcela única   9[02]
#          detalhe << '00'                                                   # Grupo de Valor: "00"                  9[02]
#          detalhe << '   '                                                  # Complemento do Registro: Brancos      X[03]
#          detalhe << modalidade_carteira # Tipo de Emissão                       9[01]
#          detalhe << carteira # codigo da carteira                    9[02]
#          detalhe << cod_banco                                              # codigo banco                          9[03]
#          detalhe << agencia                                                # Prefixo da Cooperativa                9[4]
#          detalhe << digito_agencia                                         # Digito da Cooperativa                 9[1]
#
#          # "Espécie do Título :
#          # 01 = Duplicata Mercantil
#          # 02 = Nota Promissória
#          # 03 = Nota de Seguro
#          # 05 = Recibo
#          # 06 = Duplicata Rural
#          # 08 = Letra de Câmbio
#          # 09 = Warrant
#          # 10 = Cheque
#          # 12 = Duplicata de Serviço
#          # 13 = Nota de Débito
#          # 14 = Triplicata Mercantil
#          # 15 = Triplicata de Serviço
#          # 18 = Fatura
#          # 20 = Apólice de Seguro
#          # 21 = Mensalidade Escolar
#          # 22 = Parcela de Consórcio
#          # 99 = Outros"
#          detalhe << pagamento.especie_titulo                               # Espécie de documento                  9[02]
#          detalhe << '0'                                                    # aceite (A=1/N=0)                      X[01]
#
#          # "Primeira instrução codificada:
#          # Regras de impressão de mensagens nos boletos:
#          # * Primeira instrução (SEQ 34) = 00 e segunda (SEQ 35) = 00, não imprime nada.
#          # * Primeira instrução (SEQ 34) = 01 e segunda (SEQ 35) = 01, desconsidera-se as instruções CNAB e imprime as mensagens relatadas no trailler do arquivo.
#          # * Primeira e segunda instrução diferente das situações acima, imprimimos o conteúdo CNAB:
#          # 00 = AUSENCIA DE INSTRUCOES
#          # 01 = COBRAR JUROS
#          # 03 = PROTESTAR 3 DIAS UTEIS APOS VENCIMENTO
#          # 04 = PROTESTAR 4 DIAS UTEIS APOS VENCIMENTO
#          # 05 = PROTESTAR 5 DIAS UTEIS APOS VENCIMENTO
#          # 07 = NAO PROTESTAR
#          # 10 = PROTESTAR 10 DIAS UTEIS APOS VENCIMENTO
#          # 15 = PROTESTAR 15 DIAS UTEIS APOS VENCIMENTO
#          # 20 = PROTESTAR 20 DIAS UTEIS APOS VENCIMENTO
#          # 22 = CONCEDER DESCONTO SO ATE DATA ESTIPULADA
#          # 42 = DEVOLVER APOS 15 DIAS VENCIDO
#          # 43 = DEVOLVER APOS 30 DIAS VENCIDO"
#          detalhe << '00'                                                   # Instrução para o título               9[02]
#          detalhe << '00'                                                   # Número de dias válidos para instrução 9[02]
#          detalhe << pagamento.formata_valor_mora(6)                        # valor mora ao dia                     9[06]
#          detalhe << pagamento.formata_valor_multa(6)                       # taxa de multa                         9[06]
#          detalhe << distribuicao_boleto                                    # indentificacao entrega                9[01]
#          detalhe << pagamento.formata_data_desconto                        # data limite para desconto             9[06]
#          detalhe << pagamento.formata_valor_desconto                       # valor do desconto                     9[13]
#
#          # "193-193 – Código da moeda
#          # 194-205 – Valor IOF / Quantidade Monetária: ""000000000000""
#          # Se o código da moeda for REAL, o valor restante representa o IOF.
#          # Se o código da moeda for diferente de REAL, o valor restante será a quantidade monetária.
#          detalhe << pagamento.formata_valor_iof                            # valor do iof                          9[13]
#          detalhe << pagamento.formata_valor_abatimento                     # valor do abatimento                   9[13]
#
#
#          # "Observações/Mensagem ou Sacador/Avalista:
#          # Quando o SEQ 14 – Indicativo de Mensagem ou Sacador/Avalista - for preenchido com Brancos,
#          # as informações constantes desse campo serão impressas no campo “texto de responsabilidade da Empresa”,
#          # no Recibo do Sacado e na Ficha de Compensação do boleto de cobrança.
#          # Quando o SEQ 14 – Indicativo de Mensagem ou Sacador/Avalista - for preenchido com “A” ,
#          # este campo deverá ser preenchido com o nome/razão social do Sacador/Avalista"
#          detalhe << ''.rjust(40, ' ') #                                       X[40]
#
#          # "Número de Dias Para Protesto:
#          # Quantidade dias para envio protesto. Se = ""0"",
#          # utilizar dias protesto padrão do cliente cadastrado na cooperativa. "
#          detalhe << '00'                                                   # Número de Dias Para Protesto          x[02]
#          detalhe << ' '                                                    # Brancos                               X[1]
#          detalhe << sequencial.to_s.rjust(6, '0')                          # numero do registro no arquivo         9[06]
#          detalhe
        end

        # Trailer do arquivo remessa
        #
        # @param sequencial
        #   num. sequencial do registro no arquivo
        #
        # @return [String]
        #
        def monta_trailer(sequencial)
          # CAMPO   TAMANHO  VALOR
          # 1 001 001 001 9(01) Identificação Registro Trailler: "9"
          # 2 002 194 193 X(193) Complemento do Registro: Brancos
          # 3 195 234 040 X(40) "Mensagem responsabilidade Beneficiário:
          #   Quando o SEQ 34 = ""01"" e o SEQ 35 = ""01"", preencher com mensagens/intruções de responsabilidade do Beneficiário
          #   Quando o SEQ 34 e SEQ 35 forem preenchidos com valores diferentes destes, preencher com Brancos"
          # 4 235 274 040 X(40) "Mensagem responsabilidade Beneficiário:
          #   Quando o SEQ 34 = ""01"" e o SEQ 35 = ""01"", preencher com mensagens/intruções de responsabilidade do Beneficiário
          #   Quando o SEQ 34 e SEQ 35 forem preenchidos com valores diferentes destes, preencher com Brancos"
          # 5 275 314 040 X(40) "Mensagem responsabilidade Beneficiário:
          #   Quando o SEQ 34 = ""01"" e o SEQ 35 = ""01"", preencher com mensagens/intruções de responsabilidade do Beneficiário
          #   Quando o SEQ 34 e SEQ 35 forem preenchidos com valores diferentes destes, preencher com Brancos"
          # 6 315 354 040 X(40) "Mensagem responsabilidade Beneficiário:
          #   Quando o SEQ 34 = ""01"" e o SEQ 35 = ""01"", preencher com mensagens/intruções de responsabilidade do Beneficiário
          #   Quando o SEQ 34 e SEQ 35 forem preenchidos com valores diferentes destes, preencher com Brancos"
          # 7 355 394 040 X(40) "Mensagem responsabilidade Beneficiário:
          #   Quando o SEQ 34 = ""01"" e o SEQ 35 = ""01"", preencher com mensagens/intruções de responsabilidade do Beneficiário
          #   Quando o SEQ 34 e SEQ 35 forem preenchidos com valores diferentes destes, preencher com Brancos"
          # 8 395 400 006 9(06) Seqüencial do Registro: Incrementado em 1 a cada registro

          "91#{cod_banco}#{convenio}#{''.rjust(384, ' ')}#{sequencial.to_s.rjust(6, '0')}"
        end
      end
    end
  end
end
