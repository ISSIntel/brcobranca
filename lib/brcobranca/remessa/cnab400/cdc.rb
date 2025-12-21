# -*- encoding: utf-8 -*-
#
module Brcobranca
  module Remessa
    module Cnab400
      class Cdc < Brcobranca::Remessa::Cnab400::Base
        # Número do convênio (informado pelo CDC no cadastramento)
        attr_accessor :convenio

        validates_presence_of :agencia, :conta_corrente, message: 'não pode estar em branco.'
        validates_presence_of :convenio, :sequencial_remessa, message: 'não pode estar em branco.'
        validates_length_of :convenio, maximum: 9, message: 'deve ter no máximo 9 dígitos.'
        validates_length_of :agencia, maximum: 4, message: 'deve ter 4 dígitos.'
        validates_length_of :carteira, is: 3, message: 'deve ter 3 dígitos.'

        def agencia=(valor)
          @agencia = valor.to_s.rjust(4, '0') if valor
        end

        def convenio=(valor)
          @convenio = valor.to_s.rjust(9, '0') if valor
        end

        def sequencial_remessa=(valor)
          @sequencial_remessa = valor.to_s.rjust(7, '0') if valor
        end

        def info_conta
          # Header: Posição 27-46 (20 posições)
          # Agência (4) + Convênio (9) + Brancos (7)
          info = agencia.to_s.rjust(4, '0')      # 4 posições
          info << convenio.to_s.rjust(9, '0')    # 9 posições
          info << ''.rjust(7, ' ')               # 7 posições brancos
          info
        end

        def cod_banco
          '470'
        end

        def nome_banco
          'CDC SCD'.ljust(15, ' ')
        end

        def complemento
          # Header: Posição 101-394 (294 posições) - Filler (brancos)
          ''.rjust(294, ' ')
        end

        # Remove caracteres especiais e não-ASCII
        # Mantém apenas letras, números e espaços
        def sanitize_string(str)
          str.to_s
             .gsub(/[áàâãäå]/, 'a')
             .gsub(/[éèêë]/, 'e')
             .gsub(/[íìîï]/, 'i')
             .gsub(/[óòôõö]/, 'o')
             .gsub(/[úùûü]/, 'u')
             .gsub(/[ç]/, 'c')
             .gsub(/[ñ]/, 'n')
             .gsub(/[ÁÀÂÃÄÅ]/, 'A')
             .gsub(/[ÉÈÊË]/, 'E')
             .gsub(/[ÍÌÎÏ]/, 'I')
             .gsub(/[ÓÒÔÕÖ]/, 'O')
             .gsub(/[ÚÙÛÜ]/, 'U')
             .gsub(/[Ç]/, 'C')
             .gsub(/[Ñ]/, 'N')
             .gsub(/[^A-Za-z0-9 ]/, ' ') # Remove qualquer caracter que não seja letra, número ou espaço
             .squeeze(' ') # Remove espaços duplicados
             .strip
        end

        # Formata o endereço do sacado (logradouro) - 40 caracteres
        def formata_endereco_sacado(pgto)
          endereco = sanitize_string(pgto.endereco_sacado.to_s)
          endereco.ljust(40, ' ')[0..39]
        end

        def monta_detalhe(pagamento, sequencial)
          raise Brcobranca::RemessaInvalida, pagamento if pagamento.invalid?

          # Registro tipo 1 - Detalhe (400 caracteres)
          # Baseado na documentação oficial CNAB400 CDC (cnab400grc.txt)

          detalhe = '1'                                                      # 001-001 Identificação Registro
          detalhe << identificacao_beneficiario                              # 002-003 Código Inscrição Beneficiário (01=CPF, 02=CNPJ)
          detalhe << documento_cedente.to_s.rjust(14, '0')                   # 004-017 Número Inscrição Beneficiário
          detalhe << agencia.to_s.rjust(4, '0')                              # 018-021 Agência
          detalhe << convenio.to_s.rjust(9, '0')                             # 022-030 Número do convênio
          detalhe << ''.rjust(3, ' ')                                        # 031-033 Brancos
          detalhe << ''.rjust(4, '0')                                        # 034-037 Filler (zeros)
          detalhe << ''.rjust(25, ' ')                                       # 038-062 Uso da Empresa
          detalhe << pagamento.nosso_numero.to_s.rjust(11, '0')              # 063-073 Nosso Número (11 caracteres)
          detalhe << ' '                                                     # 074-074 Filler (1 espaço em branco)
          detalhe << ''.rjust(9, '0')                                        # 075-083 Filler (zeros)
          detalhe << formata_carteira                                        # 084-086 Número da Carteira (011,012,021,041)
          detalhe << ''.rjust(12, '0')                                       # 087-098 Filler (zeros)
          detalhe << ''.rjust(10, '0')                                       # 099-108 Número do Contrato
          detalhe << pagamento.identificacao_ocorrencia                      # 109-110 Ocorrência
          detalhe << pagamento.numero_documento.to_s.rjust(10, ' ')          # 111-120 Seu Número (alinhado à direita)
          detalhe << pagamento.data_vencimento.strftime('%d%m%y')            # 121-126 Data Vencimento (DDMMAA)
          detalhe << pagamento.formata_valor                                 # 127-139 Valor Título (13 posições)
          detalhe << cod_banco                                               # 140-142 Código Banco
          detalhe << formata_agencia_com_digito                              # 143-147 Agência com dígito 9 (ex: 00019)
          detalhe << '99'                                                    # 148-149 Espécie
          detalhe << 'N'                                                     # 150-150 Aceite (A ou N)
          detalhe << pagamento.data_emissao.strftime('%d%m%y')               # 151-156 Data Emissão (DDMMAA)
          detalhe << '00'                                                    # 157-158 1ª Instrução
          detalhe << '00'                                                    # 159-160 2ª Instrução
          detalhe << pagamento.formata_valor_mora                            # 161-173 Valor Mora (13 posições)
          detalhe << pagamento.formata_data_desconto                         # 174-179 Data Limite Desconto (6 posições)
          detalhe << pagamento.formata_valor_desconto                        # 180-192 Valor Desconto (13 posições)
          detalhe << ''.rjust(13, '0')                                       # 193-205 Filler (zeros)
          detalhe << pagamento.formata_valor_abatimento                      # 206-218 Abatimento (13 posições)
          detalhe << tipo_inscricao_sacado(pagamento)                        # 219-220 Código Inscrição Pagador (01=CPF, 02=CNPJ)
          detalhe << pagamento.documento_sacado.to_s.rjust(14, '0')          # 221-234 Número Inscrição Pagador
          detalhe << sanitize_string(pagamento.nome_sacado).ljust(30, ' ')[0..29]  # 235-264 Nome Pagador
          detalhe << '001'                                                   # 265-267 Código da Modalidade (001)
          detalhe << ''.rjust(7, ' ')                                        # 268-274 Brancos
          detalhe << formata_endereco_sacado(pagamento)                      # 275-314 Logradouro (40)
          detalhe << sanitize_string(pagamento.bairro_sacado).ljust(12, ' ')[0..11]  # 315-326 Bairro (12)
          detalhe << pagamento.cep_sacado.to_s.gsub(/[^0-9]/, '').rjust(8, '0') # 327-334 CEP (8)
          detalhe << sanitize_string(pagamento.cidade_sacado).ljust(15, ' ')[0..14]  # 335-349 Cidade (15)
          detalhe << pagamento.uf_sacado.to_s.ljust(2, ' ')                  # 350-351 Estado (2)
          detalhe << ''.rjust(30, ' ')                                       # 352-381 Nome Sacador/Avalista
          detalhe << ''.rjust(13, ' ')                                       # 382-394 Brancos
          detalhe << sequencial.to_s.rjust(6, '0')                           # 395-400 Sequencial Registro

          detalhe
        end

        # Formata a carteira com 3 dígitos
        # Carteiras válidas: 011, 012, 021, 041
        def formata_carteira
          carteira_num = carteira.to_i.to_s.rjust(3, '0')
          # Se não começar com 0, adiciona o 0 inicial
          carteira_num = "0#{carteira_num}" if carteira_num.size == 2
          carteira_num[0..2]
        end

        # Formata agência com dígito 9 (5 posições)
        # Exemplo: agência 0001 → 00019
        def formata_agencia_com_digito
          "#{agencia.to_s.rjust(4, '0')}9"
        end

        # Identifica o tipo de inscrição do beneficiário (cedente)
        # 01 = CPF, 02 = CNPJ
        def identificacao_beneficiario
          documento_cedente.to_s.size <= 11 ? '01' : '02'
        end

        # Retorna tipo de inscrição do sacado (pagador)
        # Usa o campo tipo_documento_sacado se estiver preenchido
        # Senão usa o método padrão identificacao_sacado
        def tipo_inscricao_sacado(pagamento)
          if pagamento.tipo_documento_sacado.present?
            pagamento.tipo_documento_sacado
          else
            pagamento.identificacao_sacado
          end
        end
      end
    end
  end
end
