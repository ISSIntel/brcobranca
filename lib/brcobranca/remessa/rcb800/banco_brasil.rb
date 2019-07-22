# -*- encoding: utf-8 -*-
#
module Brcobranca
  module Remessa
    module Rcb800
      class BancoBrasil < Brcobranca::Remessa::Rcb800::Base

        # tipo de remessa producao ou teste
        attr_accessor :env_remessa

        # Convenio
        attr_accessor :convenio
        attr_accessor :tipo_cobranca

        validates_presence_of :agencia, :convenio, message: 'não pode estar em branco.'


        # Retorna dígito verificador da agência
        #
        # @return [String]
        #
        def agencia_dv
          agencia.modulo11(mapeamento: { 10 => 'X' })
        end

        # Codigo do banco
        #
        def cod_banco
          '001'
        end

        # Nome por extenso do banco
        #
        def nome_banco
          'BANCODOBRASIL'.ljust(15, ' ')
        end

#       01 (Inclusão) -  02 (Alteração) - 03 (Exclusão)
        def tipo_atualizacao(identificacao_ocorrencia)
           identificacao_ocorrencia == '01' ? identificacao_ocorrencia : '02'
        end

        def detalhamento_debito(pagamento)
          detalhe = []
          detalhe << pagamento.endereco_sacado.to_s.first(30)  # endereco pagador
          detalhe << pagamento.bairro_sacado.to_s.first(12)    # bairro do pagador
          detalhe << pagamento.cep_sacado.gsub(/[.-]/i, '')    # CEP do pagador
          detalhe << pagamento.cidade_sacado.to_s.first(15)   # cidade do pagador
          detalhe << pagamento.uf_sacado                       # UF do pagador

          detalhe.join(', ').tr("\r\n","").ljust(100, ' ')
        end

        def monta_detalhe(pagamento, sequencial)
          raise Brcobranca::RemessaInvalida, pagamento if pagamento.invalid?

          detalhe = '2'                                                        # identificacao do registro         X[1]  001 a 001
          detalhe << empresa_mae.to_s.ljust(60, ' ')                           # nome da empresa                   X[60] 002 a 061
          detalhe << tipo_atualizacao(pagamento.identificacao_ocorrencia)      # tipo da atualizacao               9[2]  062 a 063
          detalhe << pagamento.documento_sacado.to_s.rjust(14, '0')            # documento do pagador              9[14] 064 a 077
          detalhe << pagamento.identificador_debito.first(20).ljust(20, ' ')   # identifica a origem do débito.    X[20] 078 a 097
          detalhe << pagamento.data_vencimento.strftime('%m/%Y').ljust(20, ' ')# período do débito.                X[20] 098 a 117
          detalhe << detalhamento_debito(pagamento)                            # detalhamento do débito.          X[100] 118 a 217
          detalhe << pagamento.data_vencimento.strftime('%Y%m%d')              # data de vencimento                9[08] 218 a 225
          detalhe << pagamento.codigo_barras.to_s.ljust(48, ' ')               # codigo de barras                  x[48] 226 a 273
          detalhe << pagamento.formata_valor(11)                               # valor do titulo                   9[11] 274 a 284  # VERIFICAR
          detalhe << '09'                                                      # tipo debito 09- IPTU              9[02] 285 a 286
          detalhe << '000'                                                     # numero parcela                    9[03] 287 a 289  # VERIFICAR
          detalhe << ' '*17                                                    # complemento                       X[17] 290 a 306
          detalhe << ' '*11                                                    # complemento                       X[11] 307 a 317
          detalhe << pagamento.codigo_barras.to_s.ljust(48, ' ')                # cod barra cota unica sem desconto x[48] 318 a 365
          detalhe << pagamento.identificacao_sacado.to_s.last                  # tipo pagador                      X[01] 366 a 366
          detalhe << ' '*75                                                    # complemento                       X[75] 367 a 441
          detalhe << sequencial.to_s.rjust(9, '0')                             # sequencial do registro            9[09] 442 a 450
        end
      end
    end
  end
end
