# -*- encoding: utf-8 -*-
#
module Brcobranca
  module Remessa
    module Rcb800
      class Base < Brcobranca::Remessa::Base
        # documento do cedente
        attr_accessor :documento_cedente

        # Data da geracao do arquivo seguindo o padrao AAAAMMDD
        #
        # @return [String]
        #
        def data_geracao(extra=0)
          (Date.current+extra.day).strftime('%Y%m%d')
        end

        # Header do arquivo remessa
        #
        # @return [String]
        #
        def monta_header
                                                           # CAMPO                 TAMANHO    VALOR
          header = 'A'                                     # tipo do registro      x[1]        A
          header << convenio.to_s.rjust(6, '0')            # convenio              9[6]
          header << data_geracao.to_s                      # data geracao arq      9[8]
          header << 'RCB800 '                              # ident. arquivo        x[7]        RCB800
          header << env_remessa.to_s.ljust(2, ' ')         # tipo arquivo          x[2]        T ou P
          header << agencia.to_s.first(4)                  # agencia sem digito    9[4]
          header << Date.current.year.to_s                 # ano remessa           9[4]
          header << sequencial_remessa.to_s.rjust(5, '0')  # numero remessa        9[5]
          header << data_geracao.to_s                      # inicio vigencia       9[8]
          header << data_geracao(365).to_s                 # fim vigencia          9[8]
          header << '105124422'                            # codigo cliente MCI    9[9]
          header << ' '*379                                # complemento registro  x[379]
          header << '000000001'                            # num. sequencial       9[5]        00001
          header
        end

        # Trailer do arquivo remessa
        def monta_trailer(contador)
          trailer = 'Z'                                #identificacao registro  X[1]      Z
          trailer << (contador-1).to_s.rjust(9, '0')       #total registros         9[9]
          trailer << ' '*431                           # complemento            X[431]
          trailer << (contador+1).to_s.rjust(9, '0')   # num. sequencial        9[9]
          trailer
        end

        # Registro detalhe do arquivo remessa
        #
        # Este metodo deve ser sobrescrevido na classe do banco
        #
        def monta_detalhe(_pagamento, _sequencial)
          raise Brcobranca::NaoImplementado, 'Sobreescreva este método na classe referente ao banco que você esta criando'
        end

        # Gera o arquivo com os registros
        #
        # @return [String]
        def gera_arquivo
          raise Brcobranca::RemessaInvalida, self unless valid?

          # contador de registros no arquivo
          contador = 1
          ret = [monta_header]
          pagamentos.each do |pagamento|
            contador += 1
            ret << monta_detalhe(pagamento, contador)
          end
          ret << monta_trailer(contador)

          remittance = ret.join("\n").to_ascii.upcase
          remittance << "\n"

          remittance.encode(remittance.encoding, universal_newline: true).encode(remittance.encoding, crlf_newline: true)
        end

        # Informacoes referentes a conta do cedente
        #
        # Este metodo deve ser sobrescrevido na classe do banco
        #
        def info_conta
          raise Brcobranca::NaoImplementado, 'Sobreescreva este método na classe referente ao banco que você esta criando'
        end

        # Numero do banco na camara de compensacao
        #
        # Este metodo deve ser sobrescrevido na classe do banco
        #
        def cod_banco
          raise Brcobranca::NaoImplementado, 'Sobreescreva este método na classe referente ao banco que você esta criando'
        end

        # Nome por extenso do banco cobrador
        #
        # Este metodo deve ser sobrescrevido na classe do banco
        #
        def nome_banco
          raise Brcobranca::NaoImplementado, 'Sobreescreva este método na classe referente ao banco que você esta criando'
        end

        # Complemento do registro header
        #
        # Este metodo deve ser sobrescrevido na classe do banco
        #
        def complemento
          raise Brcobranca::NaoImplementado, 'Sobreescreva este método na classe referente ao banco que você esta criando'
        end
      end
    end
  end
end
