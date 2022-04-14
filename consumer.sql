CREATE OR REPLACE PACKAGE BODY C_Int_Magento_Consu_Util_API IS

-----------------------------------------------------------------------------
-------------------- PRIVATE DECLARATIONS -----------------------------------
-----------------------------------------------------------------------------


-----------------------------------------------------------------------------
-------------------- LU SPECIFIC PUBLIC METHODS -----------------------------
-----------------------------------------------------------------------------

PROCEDURE Process_Magento_Consumer_Notif
IS
   
   PROCEDURE Cust
   IS
   
      l_host_name_   VARCHAR2 (128);
      token_         VARCHAR2(1000);
      isProductionServer_    NUMBER;
      
   BEGIN
      
      --   isProductionServer_ := 0 ambiente TST e SUP
      --   isProductionServer_ := 1 ambiente PRD
      isProductionServer_ := 1;
      isProductionServer_ := C_RB_UTIL_API.C_IS_PRODUCTION_SERVER;
   
      IF isProductionServer_ = 0 THEN
          RETURN;
      END IF;
   
      Gerar_Token(token_, l_host_name_);
   
      IF NVL(token_, 'dUmMy') <> 'dUmMy' THEN
          Execute_Cliente(token_,  l_host_name_); -- amiranda 19/01/2022 as 22:50hrs
          Execute_Produto(token_,  l_host_name_);
          Execute_Foto(token_,  l_host_name_);
          Execute_Preco(token_,  l_host_name_);
          Execute_Impostos_Icms(token_,  l_host_name_);
          Execute_Condicao_Pagamento (token_,  l_host_name_);
          Execute_Dados_Pedido_Consumer (token_,  l_host_name_);
          --Execute_Ordens (); -- amiranda 19/01/2022 as 22:50hrs
          --Execute_Status_Ordem (token_,  l_host_name_); -- amiranda 19/01/2022 as 22:50hrs
          Execute_Produto(token_,  l_host_name_); -- amiranda 19/01/2022 as 22:50hrs
      END IF;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Process_Magento_Consumer_Notif');
   Cust;
END Process_Magento_Consumer_Notif;


PROCEDURE Execute_Cliente(token_ IN VARCHAR2,  host_name_ IN VARCHAR2)
IS
   
   PROCEDURE Cust(token_ IN VARCHAR2,  host_name_ IN VARCHAR2)
   IS
      
      l_clob_request     CLOB;
      l_clob_response    CLOB;
      error_             VARCHAR2(5);
      json_end_          VARCHAR2(32000);
      json_contatos_     VARCHAR2(32000);
      json_order_type_   VARCHAR2(32000);
      numero_end_        CUSTOMER_ORDER_ADDRESS.address1%TYPE;
      endereco_01_       CUSTOMER_ORDER_ADDRESS.address1%TYPE;
      cliente_existe_    VARCHAR2(5);
      posicao_virgula_   NUMBER;
      external_id_type_order_ VARCHAR2(50);
      external_id_contato_  NUMBER; 
      count_                NUMBER;
      i_                    NUMBER;
   
      CURSOR get_cliente(code_ IN VARCHAR2) IS
                                               SELECT
                                                    a.customer_id                                                        AS codigo_cliente
                                                   ,convertToUnicode(NVL(a.name,convertToUnicode(CUSTOMER_INFO_API.Get_Name(A.customer_id))))                                    AS apelido
                                                   ,convertToUnicode(CUSTOMER_INFO_API.Get_Name(A.customer_id))          AS razao_social
                                                   ,a.customer_id || '@riobranco.com.br'                                 AS email_empresa_padrao
                                                   ,NVL(e.credit_limit,0)                                                AS limite_credito
                                                   ,LOWER(NVL(f.c_national_simple_db,'false'))                           AS simples_nacional_flag
                                                   ,LOWER(NVL(f.icms_tax_payer,'false'))                                 AS contribuite_icms_flag
                                                   ,LOWER(NVL(f.final_consumer,'false'))                                 AS consumidor_final
                                                   ,CASE WHEN NVL(g.suframa_registration,'SEMREG') <> 'SEMREG' AND TRUNC(g.suframa_registration_date) > = TRUNC(SYSDATE) THEN 
                                                         'true' 
                                                         ELSE 'false' 
                                                     END                                                                 AS suframa_flag
                                                    ,CASE WHEN UPPER(G.state_registration) LIKE ('ISENT%') THEN 'true' ELSE 'false' END  AS ie_isento_flag
                                                    ,LOWER(NVL(SALES_PART_SALESMAN_API.Get_C_Bolsao_Salesman(i.vendor_id ),'false'))     AS bolsao_flag
                                                    ,convertToUnicode(i.vendor_id)                                                       AS vendedor
                                                    ,CASE WHEN i.business_unit = 'MAXPRINT' THEN 'consumer_maxprint'
                                                     WHEN i.business_unit = 'BOBINAS'  THEN 'consumer_bobinas'
                                                     WHEN i.business_unit = 'PROVEDOR' THEN 'consumer_isp' END AS store_code
                                               FROM CUSTOMER_INFO_ADDRESS a
                                               INNER JOIN CUSTOMER_CREDIT_INFO_TAB e
                                                   ON a.customer_id = e.identity
                                               INNER JOIN CUSTOMER_TAX_INFO_BR f
                                                   ON a.customer_id = f.customer_id  AND a.address_id = f.address_id
                                               INNER JOIN CUSTOMER_BR_TAX_INFO g
                                                   ON a.customer_id = g.customer_id AND a.address_id = g.address_id
                                               INNER JOIN C_CUSTOMER_PORT_OVERVIEW i
                                                   ON a.customer_id = i.customer_id
                                               WHERE A.PARTY_TYPE_DB = 'CUSTOMER'
                                                     AND i.business_unit IN ('MAXPRINT') --('MAXPRINT', 'BOBINAS', 'PROVEDOR') 
                                                     AND a.address_id = '000'
                                                     AND NVL(I.portfolio_default, 'FALSE') = 'TRUE'
                                                     AND A.customer_id = code_;
   
   
      CURSOR get_sellers_num_(code_ IN VARCHAR2) IS
                                               SELECT COUNT(*) AS count_ 
                                               FROM CUSTOMER_INFO_ADDRESS a
                                               INNER JOIN CUSTOMER_CREDIT_INFO_TAB e
                                                   ON a.customer_id = e.identity
                                               INNER JOIN CUSTOMER_TAX_INFO_BR f
                                                   ON a.customer_id = f.customer_id  AND a.address_id = f.address_id
                                               INNER JOIN CUSTOMER_BR_TAX_INFO g
                                                   ON a.customer_id = g.customer_id AND a.address_id = g.address_id
                                               INNER JOIN C_CUSTOMER_PORT_OVERVIEW i
                                                   ON a.customer_id = i.customer_id
                                               WHERE A.PARTY_TYPE_DB = 'CUSTOMER'
                                                     AND i.business_unit IN ('MAXPRINT') --('MAXPRINT', 'BOBINAS', 'PROVEDOR') 
                                                     AND a.address_id = '000'
                                                     AND NVL(I.portfolio_default, 'FALSE') = 'TRUE'
                                                     AND A.customer_id = code_;
                                                     
      CURSOR get_sellers_ids_(code_ IN VARCHAR2) IS
                                               SELECT
                                                     convertToUnicode(i.vendor_id)  AS vendedor
                                                    ,CASE WHEN i.business_unit = 'MAXPRINT' THEN 'consumer_maxprint'
                                                     WHEN i.business_unit = 'BOBINAS'  THEN 'consumer_bobinas'
                                                     WHEN i.business_unit = 'PROVEDOR' THEN 'consumer_isp' END AS store_code
                                               FROM CUSTOMER_INFO_ADDRESS a
                                               INNER JOIN CUSTOMER_CREDIT_INFO_TAB e
                                                   ON a.customer_id = e.identity
                                               INNER JOIN CUSTOMER_TAX_INFO_BR f
                                                   ON a.customer_id = f.customer_id  AND a.address_id = f.address_id
                                               INNER JOIN CUSTOMER_BR_TAX_INFO g
                                                   ON a.customer_id = g.customer_id AND a.address_id = g.address_id
                                               INNER JOIN C_CUSTOMER_PORT_OVERVIEW i
                                                   ON a.customer_id = i.customer_id
                                               WHERE A.PARTY_TYPE_DB = 'CUSTOMER'
                                                     AND i.business_unit IN ('MAXPRINT') --('MAXPRINT', 'BOBINAS', 'PROVEDOR') 
                                                     AND a.address_id = '000'
                                                     AND NVL(I.portfolio_default, 'FALSE') = 'TRUE'
                                                     AND A.customer_id = code_;                                               
                                                        
   
      CURSOR get_cliente_end(code_ IN VARCHAR2) IS
                                                   SELECT
                                                      a.customer_id||A.address_id                                           AS ID
                                                      ,a.country_db                                                         AS sigla_pais
                                                      ,SUBSTR(STATE_CODES_API.Get_State_Name(a.country_db, a.state),1,200)  AS estado
                                                      ,SUBSTR(a.state,1,2)                                                  AS uf
                                                      ,SUBSTR(a.city,1,200)                                                 AS cidade
                                                      ,REPLACE(SUBSTR(a.zip_code,1,10),'-','')                              AS cep
                                                      ,a.address1                                                           AS endereco
                                                      ,a.address2                                                           AS complemento
                                                      ,g.district                                                           AS bairro
                                                      ,CASE WHEN A.ADDRESS_ID = '000' THEN 'true' ELSE 'false' END          AS end_default
                                                   FROM CUSTOMER_INFO_ADDRESS a
                                                   INNER JOIN CUSTOMER_BR_TAX_INFO g
                                                      ON  a.customer_id = g.customer_id AND a.address_id = g.address_id
                                                   WHERE a.party_type_db = 'CUSTOMER'
                                                         AND a.customer_id = code_;
   
      CURSOR get_cliente_contatos(code_ IN VARCHAR2) IS
                                                      SELECT DISTINCT a.name                   AS name_db,
                                                                      convertToUnicode(a.name) AS contato,
                                                                      convertToUnicode(a.description) AS cargo_,
                                                                      a.name AS contato_db
                                                      FROM COMM_METHOD a
                                                      WHERE A.IDENTITY = code_
                                                            AND A.party_type_db = 'CUSTOMER' 
                                                            AND A.METHOD_ID_DB IN (Comm_Method_Code_API.Get_Db_Value(0), 
                                                                                   Comm_Method_Code_API.Get_Db_Value(1), 
                                                                                   Comm_Method_Code_API.Get_Db_Value(5)
                                                                                   ) 
                                                            AND NVL(A.description, 'dUmMy') <> 'dUmMy';
   
      CURSOR get_list_notifications IS
                                    SELECT   ID AS id,
                                             CODE AS code,
                                             ENTITY AS entidadeIntegrador,
                                             ID AS codigo,
                                             OPERATION AS operacaoIntegrador
                                    FROM  C_MAGENTO_Pv_Consumer_ACT
                                    WHERE TIMESTAMP IS NULL AND
                                          ENTITY = 'CL'
                                    ORDER BY TIMESTAMP_CREATION;
   
      CURSOR get_order_type (customer_id_ IN VARCHAR2) IS SELECT 
                                                            a.price_list_no|| '-' || a.deposit_id ||'-' ||a.operation_type as external_id_,
                                                            a.price_list_no || ' - ' || 
                                                            convertToUnicode(SALES_PRICE_LIST_API.Get_Description(a.price_list_no) || ' - ' || 
                                                            a.operation_type || ' - '  || a.deposit_id)  AS label_
                                                            ,a.price_list_no  AS price_list_id_
                                                            ,a.deposit_id      AS stock_
                                                            ,a.operation_type  AS nf_issuer_
                                                            , CASE WHEN a.operation_type LIKE '%B' THEN 'consumer_bobinas'
                                                                   WHEN a.operation_type LIKE '%P' THEN 'consumer_isp'
                                                                   WHEN a.operation_type LIKE '%M' THEN 'consumer_maxprint'
                                                              END AS store_code_  
                                                          FROM C_PRICE_LIST_AVAIL_WEB a
                                                          WHERE a.customer_id = customer_id_;
   BEGIN
   
      cliente_existe_ := 'TRUE';
   
      FOR rec_ IN get_list_notifications LOOP
           --INSERT OR UPDATE NOTIFICATIONS
         FOR rec_cliente_ IN get_cliente(rec_.code) LOOP
            json_end_ := '"addresses":[';                 
            FOR rec_end_ IN get_cliente_end(rec_.code) LOOP
               IF LENGTH(json_end_) > 20 THEN
                  json_end_ := json_end_ || ',';
               END IF;
   
               posicao_virgula_ := NVL(INSTR(rec_end_.endereco,',',1),0);
   
               IF posicao_virgula_ > 0 THEN 
                  endereco_01_     := SUBSTR(rec_end_.endereco,1,posicao_virgula_ - 1);
                  numero_end_      := SUBSTR(rec_end_.endereco,posicao_virgula_ + 1, LENGTH(rec_end_.endereco));
               ELSE
                  endereco_01_     := rec_end_.endereco;
                  numero_end_      := 'S/N';
               END IF;  
   
               json_end_ := json_end_ || '{
                                          "external_id":"' ||rec_end_.id||'",
                                          "postcode":"' ||rec_end_.cep||'",
                                          "street":"' ||endereco_01_||'",
                                          "number": "' || numero_end_ || '",
                                          "complement":"' ||rec_end_.complemento||'",
                                          "district":"' ||rec_end_.bairro||'",
                                          "city":"' ||rec_end_.cidade||'",
                                          "country_id":"' || rec_end_.sigla_pais || '",
                                          "region":"' ||rec_end_.uf||'",
                                          "telephone":"' || '.' || '",
                                          "is_default":' || rec_end_.end_default || ',
                                          "is_active": "true" 
                                          }';
            END LOOP;
            json_end_ := json_end_ || ']';
   
            json_contatos_ := '"contacts":[';
            FOR rec_contato_ IN get_cliente_contatos(rec_.code) LOOP
   
               get_ID_Contato_Cliente(rec_cliente_.codigo_cliente, rec_contato_.name_db, external_id_contato_);
   
               IF LENGTH(json_contatos_) > 20 THEN
                  json_contatos_ := json_contatos_ || ',';
               END IF;
               json_contatos_ := json_contatos_ || '{
                                 "external_id":' || external_id_contato_ || ',
                                 "first_name":"' || rec_contato_.contato || '",
                                 "telephone":"' || NVL(get_contato_telefone(rec_.code, rec_contato_.contato_db), get_contato_celular(rec_.code, rec_contato_.contato_db)) || '",
                                 "email":"' || get_contato_email(rec_.code, rec_contato_.contato_db) || '",
                                 "job_title":"'  || rec_contato_.cargo_ || '",
                                 "is_active":1
                              }';
            END LOOP;
            json_contatos_ := json_contatos_ || ']';
   
            json_order_type_ := '[';
            FOR rec_order_type_ IN get_order_type(rec_.code) LOOP
   
               IF json_order_type_ <> '[' THEN
                  json_order_type_ := json_order_type_ || ',';
               END IF;
   
               json_order_type_ := json_order_type_ || '{';
               json_order_type_ := json_order_type_ || '"external_id":"' || rec_order_type_.external_id_ || '",';
               json_order_type_ := json_order_type_ || '"label":"' || rec_order_type_.label_ || '",';
               json_order_type_ := json_order_type_ || '"stock":"'|| rec_order_type_.Stock_ || '",';
               json_order_type_ := json_order_type_ || '"price_list_id":"' || rec_order_type_.price_list_id_ || '",';
               json_order_type_ := json_order_type_ || '"nf_issuer_uf":"'|| rec_order_type_.nf_issuer_ || '",';
               json_order_type_ := json_order_type_ || '"is_active": true,';
               json_order_type_ := json_order_type_ || '"store_code":"'|| rec_order_type_.store_code_ || '"';
               json_order_type_ := json_order_type_ || '}' || CHR(10);
            END LOOP;
   
            json_order_type_ := json_order_type_ || ']';                    
   
            l_clob_request := '{
                                  "company":{
                                  "status":1,
                                  "company_name":"' ||rec_cliente_.razao_social||'",
                                  "legal_name":"' ||rec_cliente_.apelido||'",
                                  "company_email":"' || rec_cliente_.email_empresa_padrao || '",
                                  "vat_tax_id":"' ||rec_cliente_.codigo_cliente||'",
                                  "customer_group_id":1,
                                  "extension_attributes":{' || json_end_ || ',' || json_contatos_ || ',
                                  "tax":{
                                     "credit_limit_amount":' || rec_cliente_.limite_credito ||',
                                     "open_billet_amount":0,
                                     "expired_billet_amount":0,
                                     "credit_rma_amount":0,
                                     "is_suframa":' || rec_cliente_.suframa_flag || ',
                                     "is_simple_national_option":'|| rec_cliente_.simples_nacional_flag || ',
                                     "is_icms_contributor":'|| rec_cliente_.contribuite_icms_flag || ',
                                     "is_isent_state_registration":'|| rec_cliente_.ie_isento_flag || '
                                  },
                                  
                                  "consumer_attributes":[';
                                  
                                  OPEN get_sellers_num_(rec_cliente_.codigo_cliente);
                                  FETCH get_sellers_num_ 
                                     INTO count_;
                                  CLOSE get_sellers_num_;
                                  
                                  i_ := 0;
                                  
                                  FOR rec_sellers_ IN get_sellers_ids_(rec_cliente_.codigo_cliente) LOOP
                                  
                                     i_ := i_ + 1;
                                  
                                     l_clob_request := l_clob_request ||
                                   
                                     '{
                                      "is_bolsao":' || rec_cliente_.bolsao_flag || ',
                                      "erp_identity":"' ||rec_cliente_.codigo_cliente|| '",
                                      "sales_representative":"'|| rec_sellers_.vendedor ||'",
                                      "store_code":"'|| rec_sellers_.store_code ||'"
                                     }';
                                    
                                     IF i_ < count_ THEN
                                        l_clob_request := l_clob_request || ',';
                                     END IF;
                                  
                                  END LOOP;
                                  
                                  l_clob_request := l_clob_request ||
                                  '],';
                                  
                                  l_clob_request := l_clob_request ||
                                 '"order_type": ' || json_order_type_ ||
                               '}
                            }
                         }';
   
              dbms_output.put_line('--------------Request--------');
              dbms_output.put_line(l_clob_request);
              dbms_output.put_line('--------------Request--------');
   
            cliente_existe_ := get_cliente_existe_magento (token_ , host_name_ , rec_cliente_.CODIGO_CLIENTE );
            cliente_existe_ := UPPER(cliente_existe_); 
   
            IF NVL(cliente_existe_, 'FALSE') = 'FALSE' THEN
               dbms_output.put_line('Cliente: '||rec_cliente_.codigo_cliente||' nao existe no magento.');
               Execute_Json(token_ => token_, 
                            host_name_ => host_name_, 
                            endPoint_ => '/rest/'||rec_cliente_.store_code||'/V1/companyConsumer', 
                            method_ => 'POST', 
                            l_clob_request_ => l_clob_request, 
                            l_clob_response_ => l_clob_response, 
                            status_erro_ => error_);
            ELSE
               dbms_output.put_line('Cliente: '||rec_cliente_.codigo_cliente||' já existe no magento.');
               Execute_Json(token_ => token_, 
                              host_name_ => host_name_, 
                              endPoint_ => '/rest/'||rec_cliente_.store_code||'/V1/companyUpdate/' || rec_cliente_.CODIGO_CLIENTE, 
                              method_ => 'PUT', 
                              l_clob_request_ => l_clob_request, 
                              l_clob_response_ => l_clob_response, 
                              status_erro_ => error_);
            END IF;
            
             dbms_output.put_line('--------------Response--------');
             dbms_output.put_line('Status do erro:' || error_ );
            -- dbms_output.put_line(l_clob_response);
             dbms_output.put_line('--------------Response--------');
   
            IF error_ = 'FALSE' THEN
               Atualizar_Notificacao(rec_.id);
            ELSE
               Gravar_Log_Trigger(USER,  'ERROR Execute_Cliente: '|| rec_cliente_.codigo_cliente || substr(l_clob_response,1,1600));
               --Enviar_Email('ERROR Execute_Cliente: '|| rec_cliente_.codigo_cliente || substr(l_clob_response,1,1600),'Magento Consumer - Erro - Cadastro Cliente');
            END IF;
         END LOOP;
         COMMIT;
      END LOOP; 
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Cliente');
   Cust(token_, host_name_);
END Execute_Cliente;


FUNCTION get_perc_comission(vendor_id_ IN VARCHAR2, part_no_ IN VARCHAR2, customer_id_ IN VARCHAR2, perc_descount_ IN NUMBER) RETURN NUMBER
IS
   
   FUNCTION Cust(vendor_id_ IN VARCHAR2, part_no_ IN VARCHAR2, customer_id_ IN VARCHAR2, perc_descount_ IN NUMBER) RETURN NUMBER
   IS
      
      commission_perc_        NUMBER;
      agreement_id_           VARCHAR2(12);
      revision_no_            NUMBER;
      stat_cust_grp_          VARCHAR2(10);
      catalog_group_          VARCHAR2(10);
      sales_price_group_id_   VARCHAR2(10);
      country_code_           VARCHAR2(10);
      part_product_code_      VARCHAR2(5);
      commodity_code_         VARCHAR2(5);
      part_product_family_    VARCHAR2(5);
      group_id_               VARCHAR2(20);
      part_no_temp_           PART_CATALOG_TAB.part_no%TYPE;
      site_                   VARCHAR2(5);
   
   BEGIN
   
      IF substr(part_no_,1,1) = 'C' THEN 
         part_no_temp_ := substr(part_no_, 2,LENGTH(part_no_));
      ELSE
                  part_no_temp_ := part_no_;
      END IF;
   
      IF LENGTH(part_no_temp_) < 7 THEN
         part_no_temp_ := substr(part_no_temp_, 1, 2)|| RPAD(' ', 7-LENGTH(part_no_temp_))||substr(part_no_temp_, 3);
      END IF;
   
      site_ := get_site(part_no_temp_);
   
      agreement_id_ := Commission_Receiver_API.Get_Agreement_Id(vendor_id_);
      revision_no_ := Commission_Agree_API.Get_Agree_Version(agreement_id_, SYSDATE);
      stat_cust_grp_ := Cust_Ord_Customer_API.Get_Cust_Grp(customer_id_);
      catalog_group_ := Sales_Part_API.Get_Catalog_Group(site_, part_no_temp_);
      sales_price_group_id_ := Sales_Part_API.Get_Sales_Price_Group_Id(site_, part_no_temp_);
      country_code_ := Cust_Ord_Customer_Address_API.Get_Country_Code(customer_id_, '000');
      part_product_code_ := Inventory_Part_API.Get_Part_Product_Code(site_, part_no_temp_);
      commodity_code_ := Inventory_Part_API.Get_Prime_Commodity(site_, part_no_temp_);
      part_product_family_ := part_catalog_api.Get_C_Sales_Family(part_no_temp_) ;
   
      group_id_ := Identity_Invoice_Info_API.Get_Group_Id('RIO BRANCO', customer_id_, Party_Type_API.Decode('CUSTOMER'));
   
      C_Order_Quotation_Util_API.Calc_Com_Data_From_Agree(commission_perc_, 
                                                           agreement_id_, 
                                                           revision_no_, 
                                                           stat_cust_grp_, 
                                                           catalog_group_, 
                                                           sales_price_group_id_, 
                                                           part_no_temp_, 
                                                           country_code_, 
                                                           NULL, 
                                                           NULL, 
                                                           customer_id_, 
                                                           part_product_code_, 
                                                           commodity_code_, part_product_family_, group_id_, 1, 0, perc_descount_);
      RETURN NVL(commission_perc_, 0);
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_perc_comission');
   RETURN Cust(vendor_id_, part_no_, customer_id_, perc_descount_);
END get_perc_comission;


PROCEDURE Dados_Previsao_Chegada(codigoProduto IN VARCHAR2,
                                 dataPrevitaChegada OUT DATE,
                                 quantidade OUT NUMBER
                                 )
IS
   
   PROCEDURE Cust(codigoProduto IN VARCHAR2,
                                    dataPrevitaChegada OUT DATE,
                                    quantidade OUT NUMBER
                                    )
   IS 
   BEGIN
   
      dataPrevitaChegada := TRUNC(sysdate);
      quantidade := 1;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Dados_Previsao_Chegada');
   Cust(codigoProduto, dataPrevitaChegada, quantidade);
END Dados_Previsao_Chegada;


PROCEDURE Dados_Transp_Frete_Gratis(pesoTotal IN NUMBER,
                                    valorTotalSemImpostosOv IN NUMBER,
                                    cidadeDaEntrega IN VARCHAR2,
                                    estadoDaEntrega IN VARCHAR2,
                                    siteEstoque IN VARCHAR2,
                                    siteVenda IN VARCHAR2,                                    
                                    codigoTransportadora OUT VARCHAR2,
                                    quantidadeDiasEntrega OUT NUMBER,
                                    freteDestacado OUT VARCHAR2,
                                    nomeTransportadora OUT VARCHAR2
                                    )
IS
   
   PROCEDURE Cust(pesoTotal IN NUMBER,
                                       valorTotalSemImpostosOv IN NUMBER,
                                       cidadeDaEntrega IN VARCHAR2,
                                       estadoDaEntrega IN VARCHAR2,
                                       siteEstoque IN VARCHAR2,
                                       siteVenda IN VARCHAR2,                                    
                                       codigoTransportadora OUT VARCHAR2,
                                       quantidadeDiasEntrega OUT NUMBER,
                                       freteDestacado OUT VARCHAR2,
                                       nomeTransportadora OUT VARCHAR2
                                       )
   IS
      cod_ibge_regiao_ C_CITY_ROW.region_code%TYPE;
      cod_ibge_cidade_ C_CITY_ROW.city_code %TYPE;
      valor_total_frete_  NUMBER;
   BEGIN
   
      Pesquisar_codigo_localidade (cidadeDaEntrega, estadoDaEntrega, cod_ibge_regiao_, cod_ibge_cidade_);
      freteDestacado := get_flag_destacado (cod_ibge_regiao_ , valorTotalSemImpostosOv );
      get_valor_frete(siteEstoque, 
                       cod_ibge_cidade_, 
                       pesoTotal , 
                       valorTotalSemImpostosOv, 
                       codigoTransportadora , 
                       quantidadeDiasEntrega , 
                       valor_total_frete_);
   
      nomeTransportadora    :=  IFSRIB.FORWARDER_INFO_API.Get_Name(codigoTransportadora);
     
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Dados_Transp_Frete_Gratis');
   Cust(pesoTotal, valorTotalSemImpostosOv, cidadeDaEntrega, estadoDaEntrega, siteEstoque, siteVenda, codigoTransportadora, quantidadeDiasEntrega, freteDestacado, nomeTransportadora);
END Dados_Transp_Frete_Gratis;


PROCEDURE Dados_Transp_Frete_Nao_Gratis(pesoTotal IN NUMBER,
                                       valorTotalSemImpostosOv IN NUMBER,
                                       cidadeDaEntrega IN VARCHAR2,
                                       estadoDaEntrega IN VARCHAR2,
                                       siteEstoque IN VARCHAR2,
                                       siteVenda IN VARCHAR2,
                                       codigoTransportadora OUT VARCHAR2,
                                       quantidadeDiasEntrega OUT NUMBER,
                                       freteDestacado OUT VARCHAR2,
                                       valor_frete_cobrado OUT NUMBER,
                                       nomeTransportadora OUT VARCHAR2
                                       )
IS
   
   PROCEDURE Cust(pesoTotal IN NUMBER,
                                          valorTotalSemImpostosOv IN NUMBER,
                                          cidadeDaEntrega IN VARCHAR2,
                                          estadoDaEntrega IN VARCHAR2,
                                          siteEstoque IN VARCHAR2,
                                          siteVenda IN VARCHAR2,
                                          codigoTransportadora OUT VARCHAR2,
                                          quantidadeDiasEntrega OUT NUMBER,
                                          freteDestacado OUT VARCHAR2,
                                          valor_frete_cobrado OUT NUMBER,
                                          nomeTransportadora OUT VARCHAR2
                                          )
   IS
      
      cod_ibge_regiao_ C_CITY_ROW.region_code%TYPE;
      cod_ibge_cidade_ C_CITY_ROW.city_code %TYPE;
      
   BEGIN
   
      Pesquisar_codigo_localidade (cidadeDaEntrega, estadoDaEntrega, cod_ibge_regiao_, cod_ibge_cidade_);
      freteDestacado := get_flag_destacado (cod_ibge_regiao_ , valorTotalSemImpostosOv );
      get_valor_frete(siteEstoque, 
                      cod_ibge_cidade_, 
                      pesoTotal , 
                      valorTotalSemImpostosOv, 
                      codigoTransportadora , 
                      quantidadeDiasEntrega , 
                      valor_frete_cobrado);
   
      nomeTransportadora   :=  FORWARDER_INFO_API.Get_Name(codigoTransportadora);
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Dados_Transp_Frete_Nao_Gratis');
   Cust(pesoTotal, valorTotalSemImpostosOv, cidadeDaEntrega, estadoDaEntrega, siteEstoque, siteVenda, codigoTransportadora, quantidadeDiasEntrega, freteDestacado, valor_frete_cobrado, nomeTransportadora);
END Dados_Transp_Frete_Nao_Gratis;


PROCEDURE Simulacao_Margem(codigoCliente          IN VARCHAR2,
                           codigoVendedor         IN VARCHAR2,
                           prazoMedioPagamento    IN NUMBER,
                           listaPreco             IN VARCHAR2,
                           codigoTransportadora   IN VARCHAR2,
                           codigoProduto          IN VARCHAR2,
                           quantidade             IN NUMBER,
                           valorProduto           IN NUMBER,
                           valorContribuido       OUT NUMBER,
                           percContribuido        OUT NUMBER,
                           custoVenda             OUT NUMBER,
                           margem                 OUT NUMBER,
                           credItoImpostos        OUT NUMBER,
                           valorIcmsNaoPresencial OUT NUMBER,                           
                           verba_total            OUT NUMBER,
                           verba_real             OUT NUMBER,
                           verba_bugdet           OUT NUMBER,
                           perc_acrescimo_total   OUT NUMBER,
                           rebate                 OUT NUMBER,
                           percFrete              OUT NUMBER,
                           valorFrete             OUT NUMBER
                           )
IS
   
   PROCEDURE Cust(codigoCliente          IN VARCHAR2,
                              codigoVendedor         IN VARCHAR2,
                              prazoMedioPagamento    IN NUMBER,
                              listaPreco             IN VARCHAR2,
                              codigoTransportadora   IN VARCHAR2,
                              codigoProduto          IN VARCHAR2,
                              quantidade             IN NUMBER,
                              valorProduto           IN NUMBER,
                              valorContribuido       OUT NUMBER,
                              percContribuido        OUT NUMBER,
                              custoVenda             OUT NUMBER,
                              margem                 OUT NUMBER,
                              credItoImpostos        OUT NUMBER,
                              valorIcmsNaoPresencial OUT NUMBER,                           
                              verba_total            OUT NUMBER,
                              verba_real             OUT NUMBER,
                              verba_bugdet           OUT NUMBER,
                              perc_acrescimo_total   OUT NUMBER,
                              rebate                 OUT NUMBER,
                              percFrete              OUT NUMBER,
                              valorFrete             OUT NUMBER
                              )
   IS
      
       part_no_                  PART_CATALOG.part_no%TYPE;
       operacao_id_             C_PRICE_LIST_AVAIL_WEB.operation_id%TYPE;
       sales_contract_          C_PRICE_LIST_AVAIL_WEB.operation_type%TYPE;
       stock_contract_          C_PRICE_LIST_AVAIL_WEB.deposit_id%TYPE;
       salesman_id_             C_Custumers_Port.vendor_id%TYPE;
       total_gross_order_value_ NUMBER;
       valorContribuido_        NUMBER;
       percContribuido_         NUMBER;
       custoVenda_              NUMBER;
       margem_                  NUMBER;
       credItoImpostos_         NUMBER;
       valorIcmsNaoPresencial_  NUMBER;
       verba_total_             NUMBER;
       verba_real_              NUMBER;
       verba_bugdet_            NUMBER;
       perc_acrescimo_total_    NUMBER;
       rebate_                  NUMBER;
       percFrete_               NUMBER;
       valorFrete_              NUMBER;
       
       CURSOR Get_Salesman_id (codigoVendedor VARCHAR2) IS
          SELECT a.id_ifs 
          FROM RB_MAG_USER_ID_TO_IFS_ID_TAB a 
          WHERE a.id_magento = codigoVendedor;       
          
   BEGIN
      
      part_no_ := codigoProduto;
      
      IF SUBSTR(part_no_,1,1) = 'C' THEN
          part_no_ := SUBSTR(part_no_,2);
      END IF;
   
      IF LENGTH(part_no_) < 7 THEN
         part_no_ := substr(part_no_, 1, 2)|| RPAD(' ', 7-LENGTH(part_no_))||substr(part_no_, 3);
      END IF;
      
      OPEN Get_Salesman_id(codigoVendedor);
           FETCH Get_Salesman_id INTO salesman_id_;
      IF Get_Salesman_id%NOTFOUND THEN
         salesman_id_ := null;
      END IF;
      CLOSE Get_Salesman_id;
      
      get_info_lista_preco_web(codigoCliente , 
                               listaPreco, 
                               operacao_id_, 
                               sales_contract_, 
                               stock_contract_);
      
      total_gross_order_value_ := valorProduto * quantidade;
      
      IFSRIB.C_CALC_CONTRIBUTED_VALUE_API.Calc_Contributed_Value(sales_contract_            => sales_contract_, 
                                                                   stock_contract_            => stock_contract_, 
                                                                   customer_no_               => codigoCliente, 
                                                                   bill_addr_no_              => '000',          -- VERIFICAR
                                                                   ship_addr_no_              => '000',           -- VERIFICAR
                                                                   operation_id_              => operacao_id_, 
                                                                   not_highlight_freight_     => 'TRUE',           -- VERIFICAR
                                                                   salesman_attendant_        => codigoVendedor, 
                                                                   pay_term_id_               => prazoMedioPagamento,  -- VERIFICAR
                                                                   freight_value_             => valorFrete_, 
                                                                   total_gross_order_value_   => total_gross_order_value_,  -- VERIFICAR
                                                                   discount_percentage_       => 0,   -- VERIFICAR
                                                                   part_no_                   => part_no_, 
                                                                   item_quantity_             => quantidade, 
                                                                   base_unit_price_           => valorProduto,
                                                                   contributed_value_         => valorContribuido_,
                                                                   contributed_perc_          => percContribuido_,
                                                                   cost_sales_                => custoVenda_,
                                                                   margin                     => margem_,
                                                                   non_presential_icms_value_ => valorIcmsNaoPresencial_,
                                                                   verba_total_               => verba_total_,
                                                                   verba_real_                => verba_real_,
                                                                   verba_budget_              => verba_bugdet_,
                                                                   increase_percentage_total_ => perc_acrescimo_total_,
                                                                   rebate_                    => rebate_,
                                                                   freight_percentage_        => percFrete_);
                                                          
         valorContribuido        :=valorContribuido_;
         percContribuido         := ROUND(percContribuido_,0);
         custoVenda              := ROUND(custoVenda_,2);
         margem                  := margem_;
         credItoImpostos         := 0;
         valorIcmsNaoPresencial  := valorIcmsNaoPresencial_;                           
         verba_total             := NVL(verba_total_,0);
         verba_real              := NVL(verba_real_,0);
         verba_bugdet            := NVL(verba_bugdet_,0);
         perc_acrescimo_total    := NVL(perc_acrescimo_total_,0);
         rebate                  := NVL(rebate_,0);
         percFrete               := NVL(percFrete_,0);
         valorFrete              := NVL(valorFrete_,0);
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Simulacao_Margem');
   Cust(codigoCliente, codigoVendedor, prazoMedioPagamento, listaPreco, codigoTransportadora, codigoProduto, quantidade, valorProduto, valorContribuido, percContribuido, custoVenda, margem, credItoImpostos, valorIcmsNaoPresencial, verba_total, verba_real, verba_bugdet, perc_acrescimo_total, rebate, percFrete, valorFrete);
END Simulacao_Margem;


FUNCTION get_contato_email(customer_id_ IN VARCHAR2, name_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust(customer_id_ IN VARCHAR2, name_ IN VARCHAR2) RETURN VARCHAR2
   IS
   
      email_ VARCHAR2(200);
   
      CURSOR get_email IS
                         SELECT convertToUnicode(Z.VALUE)
                         FROM  COMM_METHOD Z 
                         WHERE Z.IDENTITY = customer_id_ AND Z.NAME = name_ AND 
                               Z.METHOD_ID_DB = Comm_Method_Code_API.Get_Db_Value(5)
                         ORDER BY Z.ADDRESS_DEFAULT DESC
                         OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
   
   BEGIN
      OPEN get_email;
      FETCH get_email INTO email_;
      CLOSE get_email;
   
      RETURN email_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_contato_email');
   RETURN Cust(customer_id_, name_);
END get_contato_email;


FUNCTION get_email_default(customer_id_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust(customer_id_ IN VARCHAR2) RETURN VARCHAR2
   IS  
      email_ VARCHAR2(200);
   
      CURSOR get_email IS
                          SELECT convertToUnicode(Z.VALUE)
                          FROM  COMM_METHOD Z WHERE Z.IDENTITY = customer_id_ AND 
                          Z.METHOD_ID_DB = Comm_Method_Code_API.Get_Db_Value(5)
                          ORDER BY Z.ADDRESS_DEFAULT DESC
                          OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
   BEGIN
      OPEN get_email;
      FETCH get_email INTO email_;
      CLOSE get_email;
   
      RETURN email_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_email_default');
   RETURN Cust(customer_id_);
END get_email_default;


FUNCTION get_contato_telefone(customer_id_ IN VARCHAR2, name_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust(customer_id_ IN VARCHAR2, name_ IN VARCHAR2) RETURN VARCHAR2
   IS 
      telefone_ VARCHAR2(200);
   
      CURSOR get_telefone IS
                          SELECT convertToUnicode(z.value)
                          FROM  COMM_METHOD Z 
                          WHERE Z.IDENTITY = customer_id_ 
                                AND Z.NAME = name_ 
                                AND Z.METHOD_ID_DB = Comm_Method_Code_API.Get_Db_Value(0)
                          ORDER BY Z.ADDRESS_DEFAULT DESC
                          OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
   BEGIN
      OPEN get_telefone;
      FETCH get_telefone INTO telefone_;
      CLOSE get_telefone;
   
      RETURN telefone_;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_contato_telefone');
   RETURN Cust(customer_id_, name_);
END get_contato_telefone;


FUNCTION get_contato_celular(customer_id_ IN VARCHAR2, name_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust(customer_id_ IN VARCHAR2, name_ IN VARCHAR2) RETURN VARCHAR2
   IS
      celular_ VARCHAR2(200);
   
      CURSOR get_celular IS
                          SELECT convertToUnicode(z.value)
                          FROM  COMM_METHOD Z 
                          WHERE Z.IDENTITY = customer_id_ 
                                AND Z.NAME = name_ 
                                AND Z.METHOD_ID_DB = Comm_Method_Code_API.Get_Db_Value(1)
                          ORDER BY Z.ADDRESS_DEFAULT DESC
                          OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
   BEGIN
      OPEN get_celular;
      FETCH get_celular INTO celular_;
      CLOSE get_celular;
   
      RETURN celular_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_contato_celular');
   RETURN Cust(customer_id_, name_);
END get_contato_celular;


FUNCTION get_cliente_existe_magento (token_ IN VARCHAR2, host_name_ IN VARCHAR2, codigo_cliente_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2, codigo_cliente_ IN VARCHAR2) RETURN VARCHAR2
   IS 
      l_clob_request  CLOB;
      l_clob_response CLOB;
      endPoint_       VARCHAR2(100);
      error_status_  VARCHAR2(100);
   
   BEGIN
   
      endPoint_ :='/rest/all/V1/companyExists/'||codigo_cliente_;
      l_clob_request:= '';
      Execute_Json(token_, host_name_, endPoint_, 'GET', l_clob_request, l_clob_response, error_status_);
   
      IF error_status_ = 'FALSE' THEN
         RETURN l_clob_response;      
      ELSE
         Gravar_Log_Trigger(USER,  'ERROR get_cliente_existe_magento: '||substr(l_clob_response,1,1600));
         RETURN 'ERRO';
      END IF;   
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_cliente_existe_magento');
   RETURN Cust(token_, host_name_, codigo_cliente_);
END get_cliente_existe_magento;


FUNCTION get_preco (lista_preco_ in VARCHAR2, codigo_produto_ IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (lista_preco_ in VARCHAR2, codigo_produto_ IN VARCHAR2) RETURN NUMBER
   IS
      
      preco_venda_ NUMBER; 
      CURSOR get_preco_venda (lista_preco__    IN VARCHAR2, 
                              codigo_produto__ IN VARCHAR2) IS SELECT NVL(a.sales_price ,0)
                                                               FROM SALES_PRICE_LIST_PART a 
                                                               WHERE a.price_list_no = lista_preco__
                                                                     AND a.catalog_no = codigo_produto__
                                                                     AND a.valid_from_date = (SELECT MAX(b.valid_from_date) 
                                                                                              FROM sales_price_list_part b
                                                                                              WHERE b.price_list_no = a.price_list_no 
                                                                                                    AND b.catalog_no = a.catalog_no 
                                                                                                    AND b.objstate = 'Active');
    BEGIN
       preco_venda_ := 0;
       OPEN get_preco_venda(lista_preco_, codigo_produto_);
       FETCH get_preco_venda INTO preco_venda_;
       CLOSE get_preco_venda;
   
       RETURN preco_venda_;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_preco');
   RETURN Cust(lista_preco_, codigo_produto_);
END get_preco;


PROCEDURE Execute_Preco (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
IS
   
   PROCEDURE Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
   IS   
   	l_clob_request  CLOB;
   	l_clob_response CLOB;
   	error_          VARCHAR2(5);
   	endPoint_       VARCHAR2(100);
   	lista_preco_    SALES_PRICE_LIST_PART.price_list_no%TYPE;
   	codigo_produto_ SALES_PRICE_LIST_PART.catalog_no%TYPE;
   	preco_venda_    NUMBER;
   	posicao_        NUMBER;
   	qtde_caract_    NUMBER;
   
   	CURSOR get_list_notifications IS
   								  SELECT   ID AS id,
   										   CODE AS code,
   										   ENTITY AS entidadeIntegrador,
   										   OPERATION AS operacaoIntegrador
   								  FROM  C_MAGENTO_Pv_Consumer_ACT
   								  WHERE TIMESTAMP IS NULL AND
   										ENTITY = 'BP'
   								  ORDER BY TIMESTAMP_CREATION;
   BEGIN
   
      FOR rec_ IN get_list_notifications LOOP
   
         qtde_caract_     := LENGTH(rec_.code);
         posicao_         := INSTR (rec_.code,'^',1);
         lista_preco_     := SUBSTR(rec_.code,1,posicao_-1);
         codigo_produto_  := SUBSTR(rec_.code,posicao_ + 1,(qtde_caract_- posicao_));
         preco_venda_     := 0;
         preco_venda_     := get_preco(lista_preco_,  codigo_produto_); 
         codigo_produto_  := REPLACE('C' || codigo_produto_,' ','');
   
         l_clob_request := '{
                        "price_list": [
                                    {
                                       "price": "' ||  REPLACE(preco_venda_,',','.') || '",
                                       "erp_identity":"' || lista_preco_ || '",
                                       "sku":"' || codigo_produto_ ||'"
                                    }
                                   ]
                        } ';
         dbms_output.put_line('Request');
         dbms_output.put_line(l_clob_request);
         dbms_output.put_line('Requestfim');
         endPoint_ := '/rest/all/V1/priceList';    
         Execute_Json(token_, host_name_, endPoint_, 'POST', l_clob_request, l_clob_response, error_);
   
         IF error_ = 'FALSE' THEN
           Atualizar_Notificacao(rec_.id);
   
         ELSE
           Gravar_Log_Trigger(USER,  'ERROR Execute_Preco: '|| codigo_produto_ ||' - ' ||substr(l_clob_response,1,1600));           
           Enviar_Email('ERROR Execute_Preco: '|| codigo_produto_ ||' - ' ||substr(l_clob_response,1,1600),'Magento Consumer - Erro - Cadastro Preco');   
         END IF;
   
         COMMIT;
      END LOOP;    
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Preco');
   Cust(token_, host_name_);
END Execute_Preco;


PROCEDURE Execute_Produto (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
IS
   
   PROCEDURE Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
   IS  
      l_clob_request  CLOB;
      l_clob_response CLOB;
      error_          VARCHAR2(5);
      endPoint_       VARCHAR2(100);
      lista_preco_    SALES_PRICE_LIST_PART.price_list_no%TYPE;
      codigo_produto_ SALES_PRICE_LIST_PART.catalog_no%TYPE;
      preco_venda_    NUMBER;
      posicao_        NUMBER;
      qtde_caract_    NUMBER;
      perc_desc_vend_ NUMBER;
      perc_desc_ger_  NUMBER;
      perc_desc_dir_  NUMBER;
      multiplo_venda_ NUMBER;     
   
      CURSOR get_list_notifications IS
                                      SELECT   ID AS id,
                                               CODE AS code,
                                               ENTITY AS entidadeIntegrador,
                                               OPERATION AS operacaoIntegrador
                                      FROM  C_MAGENTO_Pv_Consumer_ACT
                                      WHERE TIMESTAMP IS NULL AND
                                            ENTITY = 'PR'
                                      ORDER BY TIMESTAMP_CREATION;
   
      CURSOR get_produto (codigo_produto_ VARCHAR2)IS 
                                                       SELECT 
                                                           REPLACE('C' || a.part_no,' ','') AS sku_
                                                           ,convertToUnicode(a.c_comercial_description)||' '||REPLACE(a.part_no,' ','')  AS name_
                                                           ,REPLACE(a.weight_net,',','.') AS weight_
                                                           ,REPLACE(a.cubic_weight_land,',','.') AS cubic_weight_land_                                                           
                                                           ,REPLACE(NVL(b.storage_width_requirement,0),',','.') AS volume_width_
                                                           ,REPLACE(NVL(b.storage_height_requirement,0),',','.') AS volume_height_
                                                           ,REPLACE(NVL(b.storage_depth_requirement,0),',','.') AS volume_length_
                                                           ,PART_GTIN_API.Get_Default_Gtin_No(a.part_no) AS ean_
                                                           ,NVL(INVENTORY_PART_PLANNING_API.Get_Mul_Order_Qty(CASE  WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%M' THEN 'SC19M' 
                                                                                                                    WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%P' THEN 'SC19P'
                                                                                                                    WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%B' THEN 'MG09B' END, a.part_no ),0) multiplo_venda_
                                                           ,REPLACE(NVL(
                                                           c_int_magento_consu_util_api.get_qtd_estoque(a.part_no, 
                                                           CASE  WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%M' THEN 'SC19M' 
                                                                 WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%P' THEN 'SC19P'
                                                                 WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%B' THEN 'MG09B'
                                                           END),0),',','.') AS qtde_estoque_,  
                                                           CASE  WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%M' THEN 'SC19M' 
                                                                 WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%P' THEN 'SC19P'
                                                                 WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%B' THEN 'MG09B'
                                                           END AS site_,
                                                           CASE  WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%M' THEN 'consumer_maxprint' 
                                                                 WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%P' THEN 'consumer_isp'
                                                                 WHEN (SELECT IP.contract FROM INVENTORY_PART IP WHERE IP.part_no = codigo_produto_ AND ROWNUM = 1) LIKE '%B' THEN 'consumer_bobinas'
                                                                 ELSE 'all'
                                                           END AS store_code_                                                    
                                                       FROM PART_CATALOG a
                                                       LEFT JOIN PART_CATALOG_INVENT_ATTRIB b
                                                          ON a.part_no = b.part_no
                                                       WHERE a.PART_NO = codigo_produto_;
   BEGIN
   
      FOR rec_ IN get_list_notifications LOOP
         FOR rec_produto_ IN get_produto (rec_.code) LOOP
   
            perc_desc_vend_ := 0;       
            perc_desc_ger_  := 0;
            perc_desc_dir_  := 0;  
   
            IF NVL(rec_produto_.multiplo_venda_,0) = 0 THEN
               multiplo_venda_:=  1;
            ELSE
               multiplo_venda_:=  rec_produto_.multiplo_venda_;
            END IF;
   
            Pesquisar_desconto_venda(rec_.code
                                    ,rec_produto_.site_
                                    ,perc_desc_vend_
                                    ,perc_desc_ger_
                                    ,perc_desc_dir_ );
   
            l_clob_request := '
                            {
                              "product": {
                                "sku": "'||rec_produto_.sku_||'",
                                "name": "'||rec_produto_.name_||'",
                                "attribute_set_id": 4,
                                "price": 0,
                                "status": 1,
                                "visibility": 4,
                                "type_id": "simple",
                                "weight": "'||NVL(rec_produto_.cubic_weight_land_,0) ||'",
                                "extension_attributes": {
                                    "stock_item": {
                                        "qty": "' || rec_produto_.qtde_estoque_||'",
                                        "is_in_stock": true
                                    }
                                },
                                "custom_attributes": [
                                    {
                                        "attribute_code": "url_key",
                                        "value": "'||rec_produto_.sku_ ||'"
                                    },
                                    {
                                        "attribute_code": "volume_length",
                                        "value": "'||rec_produto_.volume_length_ ||'"
                                    },
                                    {
                                        "attribute_code": "volume_height",
                                        "value": "'||rec_produto_.volume_height_  ||'"
                                    },
                                    {
                                        "attribute_code": "volume_width",
                                        "value": "'||rec_produto_.weight_ ||'"
                                    },
                                    {
                                        "attribute_code": "brand",
                                        "value": "16"
                                    },
                                    {
                                        "attribute_code": "department",
                                        "value": "18"
                                    },
                                    {
                                        "attribute_code": "collective_packaging",
                                        "value": '||multiplo_venda_ ||'
                                    },
                                    {
                                        "attribute_code": "ean",
                                        "value": "'||rec_produto_.ean_ ||'"
                                    },
                                    {
                                        "attribute_code": "ncm",
                                        "value": "'|| get_ncm (rec_.code, rec_produto_.site_) ||'"
                                    },
                                    {
                                        "attribute_code": "ipi",
                                        "value": "'|| get_aliquota_ipi(rec_.code, rec_produto_.site_) ||'"
                                    },
                                                                             {
                                        "attribute_code": "sales_representative_max_discount",
                                        "value": "'|| REPLACE(perc_desc_vend_,',','.')  ||'"
                                    },
                                                                             {
                                        "attribute_code": "manager_max_discount",
                                        "value": "'|| REPLACE(perc_desc_ger_,',','.') ||'"
                                    },
                                                                             {
                                        "attribute_code": "manager_master_max_discount",
                                        "value": "'|| REPLACE(perc_desc_dir_,',','.') ||'"
                                    },
                                    {
                                        "attribute_code": "peso",
                                        "value": "' || rec_produto_.cubic_weight_land_ ||'" 
                                    },
                                     {
                                       "attribute_code": "economia_estimada",
                                       "value": "0"
                                   }
                                ]
                            }
                      }
                ';
   
            dbms_output.put_line('--------------request--------');
            dbms_output.put_line(l_clob_request);
            
            dbms_output.put_line('Store: '||rec_produto_.store_code_);
   
             endPoint_ := '/rest/'||rec_produto_.store_code_||'/V1/products';    
             Execute_Json(token_, host_name_, endPoint_, 'POST', l_clob_request, l_clob_response, error_);
   
            dbms_output.put_line('--------------response--------');
            dbms_output.put_line(l_clob_response);
   
            IF error_ = 'FALSE' THEN
              Atualizar_Notificacao(rec_.id);
   
            ELSE
              Gravar_Log_Trigger(USER,  'ERROR Execute_Produto: '|| ' PRODUTO: ' || rec_produto_.sku_ ||substr(l_clob_response,1,1600));           
             Enviar_Email('ERROR Execute_Produto: '|| ' PRODUTO: ' || rec_produto_.sku_ ||substr(l_clob_response,1,1600),'Magento Consumer - Erro - Cadastro Produto');   
            END IF;
   
           COMMIT;
         END LOOP;    
      END LOOP;    
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Produto');
   Cust(token_, host_name_);
END Execute_Produto;


PROCEDURE Execute_Impostos_Icms (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
IS
   
   PROCEDURE Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
   IS
      l_clob_request           CLOB;
      l_clob_response          CLOB;
      error_                   VARCHAR2(5);
      info_                    VARCHAR2(2000);
      endPoint_                VARCHAR2(100);
      json_temp_               VARCHAR2(32000);
      separador_               VARCHAR2(1);
      perc_carga_trib_icms_st_ NUMBER;
      perc_carga_trib_icms_    NUMBER;
      fator_icms_st_           NUMBER;
      iva_icms_st_             NUMBER;
      codigo_produto_          tax_part.part_no%TYPE;
      store_code__             VARCHAR2(25);
   
      CURSOR get_list_notifications IS
                                       SELECT ID AS id,
                                              CODE AS code,
                                              ENTITY AS entidadeIntegrador,
                                              OPERATION AS operacaoIntegrador
                                       FROM  C_MAGENTO_Pv_Consumer_ACT
                                       WHERE TIMESTAMP IS NULL AND
                                             ENTITY = 'IC'
                                      ORDER BY TIMESTAMP_CREATION;
   
      /*                
      0 - Nacional
      1 - Estrangeiro, Importacao Direta
      2 - Estrangeiro, Aquis. no Mercado Interno
      3 - Nacional, Conteudo de Importacao > 40% and <= 70%
      4 - Nacional, Contab. de Producao conforme Decreto de Lei 288/67
      5 - Nacional, Conteúdo de Importacao <= 40%
      6 - Estrangeiro, Importacao Direta, Incl. na Lista CAMEX
      7 - Estrangeiro, Aquis. no Mercado Interno, Incl. na Lista CAMEX
      8 - Nacional, Conteudo de Importacao > 70%
      */
      
      CURSOR get_imp_icms (id_mat_imposto_ NUMBER)IS SELECT REPLACE('C' || b.part_no, ' ', '') AS sku_,
                                                            b.contract as site_,
                                                            CASE WHEN B.contract LIKE '%B' THEN 'consumer_bobinas'
                                                                 WHEN B.contract LIKE '%M' THEN 'consumer_maxprint'
                                                                 WHEN B.contract LIKE '%P' THEN 'consumer_isp'
                                                            END AS store_code_,
                                                            b.nbm_id AS ncm_,
                                                            b.tax_subst_group_id AS id_grupo_icms_st_,
                                                            CASE WHEN b.acquisition_origin_db IN (1,6)
                                                                     THEN NVL(NVL(b.ipi_percentage,NBM_API.Get_Ipi_Tax_Percent(b.nbm_id)),0)
                                                                 WHEN b.acquisition_origin_db IN (3,5,8) 
                                                                      AND part_catalog_api.Get_C_Sales_Manufacturer_No(b.part_no) IN ('MAX','DAZ','GOT','RBB', 'REE', 'MGB', 'HUA', 'FUI', 'SUM', 'WEC', 'BPP')
                                                                      THEN NVL(NVL(b.ipi_percentage,NBM_API.Get_Ipi_Tax_Percent(b.nbm_id)),0)   
                                                                 ELSE 0 END  AS ipi_aliquota_,
                                                            a.STATE_SOURCE AS origem_uf_,
                                                            a.STATE_TARGET AS desino_uf_,
                                                            NVL(STATUTORY_FEE_API.Get_Percentage(a.company, a.icms_tax_code), 0) AS icms_aliquota_,
                                                            NVL(PERCEN_ICMS_BASE_RED_API.Get_Icms_Base_Red_Percent(a.company,
                                                                                                                   a.icms_tax_code),0) as icms_perc_red_base_
                                                     FROM ICMS_PERCENTAGE a
                                                     INNER JOIN TAX_PART b
                                                        ON a.icms_group_id = b.icms_group_id
                                                     WHERE a.company = 'RIO BRANCO'
                                                           AND a.STATE_SOURCE = SUBSTR(b.contract, 1, 2)
                                                           AND b.tax_part_id = id_mat_imposto_;
   
      CURSOR get_imp_icms_st (id_grupo_icms_st__ VARCHAR2,
                              origem_uf__        VARCHAR2,
                              desino_uf__        VARCHAR2) IS 
                                                               SELECT
                                                                  NVL(C.tax_subst_percentage, 0) AS icms_st_aliquota_,
                                                                  NVL(C.markup_percentage, 0) AS icms_st_iva_,
                                                                  NVL(C.reduced_tax_subst_percentage, 0) AS icms_perc_red_base_icms_
                                                               FROM TAX_SUBST_GROUP_STATE C
                                                               WHERE c.country_code = 'BR' 
                                                                     AND c.tax_subst_group = id_grupo_icms_st__
                                                                     AND c.STATE_SOURCE = origem_uf__
                                                                     AND c.STATE_TARGET = desino_uf__;
   
   BEGIN
   
      FOR rec_ IN get_list_notifications LOOP
         separador_ := '';
         json_temp_ := NULL;
         codigo_produto_ := NULL;
   
         FOR rec_imp_icms_ IN get_imp_icms (rec_.code) LOOP
            
            store_code__ := rec_imp_icms_.store_code_;
   
            fator_icms_st_ := 0;
            iva_icms_st_   := 0;
            IF NVL(json_temp_,'bLank') <> 'bLank' THEN
               separador_ := ',';   
            END IF;
            FOR rec_imp_icms_st_ IN get_imp_icms_st(rec_imp_icms_.id_grupo_icms_st_, rec_imp_icms_.origem_uf_, rec_imp_icms_.desino_uf_) LOOP
   
               perc_carga_trib_icms_ := 0;
               perc_carga_trib_icms_st_ := 0;
               fator_icms_st_ := 0;
               iva_icms_st_   := 0;
               IF NVL(json_temp_,'bLank') <> 'bLank' THEN
                  separador_ := ',';   
               END IF;
   
               perc_carga_trib_icms_ := ROUND(rec_imp_icms_.icms_aliquota_/100 * ( 1 - rec_imp_icms_.icms_perc_red_base_/100),4);
               perc_carga_trib_icms_st_ := ROUND(rec_imp_icms_st_.icms_st_aliquota_/100 * ( 1 - rec_imp_icms_st_.icms_perc_red_base_icms_/100),4);
   
               fator_icms_st_ := ((
                                 (1 + rec_imp_icms_.ipi_aliquota_/100) * (1+ rec_imp_icms_st_.icms_st_iva_/100) * perc_carga_trib_icms_st_ - perc_carga_trib_icms_
                                 )/(1 + rec_imp_icms_.ipi_aliquota_/100))*100;
               fator_icms_st_ := ROUND(fator_icms_st_,4);
   
               IF fator_icms_st_ < 0 THEN 
                  fator_icms_st_ := 0;
               END IF;   
   
               iva_icms_st_  := NVL(rec_imp_icms_st_.icms_st_iva_,0);
   
            END LOOP;
            codigo_produto_:= rec_imp_icms_.sku_;
            json_temp_ := json_temp_ || separador_;
            json_temp_ := json_temp_ || '{';
            json_temp_ := json_temp_ || '"sku": "'        || rec_imp_icms_.sku_||'",';
            json_temp_ := json_temp_ || '"orig_uf": "'    || rec_imp_icms_.site_||'",';
            json_temp_ := json_temp_ || '"dest_uf": "'    || rec_imp_icms_.desino_uf_||'",';
            json_temp_ := json_temp_ || '"icms": '        || REPLACE(TRIM(TO_CHAR(rec_imp_icms_.icms_aliquota_,'99990D999999')),',','.') ||',';
            json_temp_ := json_temp_ || '"st": '          || REPLACE(TRIM(TO_CHAR(fator_icms_st_,'99990D999999')),',','.') || ',';
            json_temp_ := json_temp_ || '"mva": '         || REPLACE(TRIM(TO_CHAR(iva_icms_st_,'99990D999999')),',','.') || ',';
            json_temp_ := json_temp_ || '"icms_suframa": ' || REPLACE(0,',','.') ||'';                
            json_temp_ := json_temp_ || '}';
   
         END LOOP;    
   
         l_clob_request := '{"tax": [ ' || json_temp_ || '] }';
   
         --dbms_output.put_line('--------------request--------');
         -- dbms_output.put_line(l_clob_request);
         endPoint_ := '/rest/'||store_code__||'/V1/productTax';    
         Execute_Json(token_, host_name_, endPoint_, 'POST', l_clob_request, l_clob_response, error_);
         dbms_output.put_line('--------------response--------');
         dbms_output.put_line(l_clob_response);
   
         IF error_ = 'FALSE' THEN
            Atualizar_Notificacao(rec_.id);
   
         ELSE
            Gravar_Log_Trigger(USER,  'ERROR Execute_Impostos_Icms: '|| codigo_produto_ || substr(l_clob_response,1,1600));           
            Enviar_Email('ERROR Execute_Impostos_Icms: '|| codigo_produto_ || substr(l_clob_response,1,1600),'Magento Consumer - Erro - Cadastro Impostos ICMS');
         END IF;
         COMMIT;
      END LOOP;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Impostos_Icms');
   Cust(token_, host_name_);
END Execute_Impostos_Icms;


PROCEDURE Execute_Condicao_Pagamento (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
IS
   
   PROCEDURE Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
   IS
      l_clob_request  CLOB;
      l_clob_response CLOB;
      error_          VARCHAR2(5);
      endPoint_       VARCHAR2(100);
   
      CURSOR get_list_notifications IS
                                      SELECT   ID AS id,
                                               CODE AS code,
                                               ENTITY AS entidadeIntegrador,
                                               OPERATION AS operacaoIntegrador
                                      FROM  C_MAGENTO_Pv_Consumer_ACT
                                      WHERE TIMESTAMP IS NULL AND
                                            ENTITY = 'CP'
                                      ORDER BY TIMESTAMP_CREATION;
   
      CURSOR get_cod_pgto (id_cond_pagto_ VARCHAR2)IS SELECT 
                                                         convertToUnicode(a.pay_term_id) AS condition_
                                                         ,ROUND(AVG (a.days_to_due_date),0) AS prazo_medio_
                                                         ,CASE WHEN a.pay_term_id = '28' THEN 'true' ELSE 'false' END AS default_
                                                      FROM PAYMENT_TERM_DETAILS a
                                                      WHERE EXISTS (SELECT 1 
                                                                    FROM PAYMENT_TERM b
                                                                    WHERE A.pay_term_id = B.pay_term_id
                                                                          AND A.company = B.COMPANY                                                           
                                                                          AND b.C_DIVISION_DB = 'M'
                                                                          AND a.pay_term_id = id_cond_pagto_
                                                                        )               
                                                      GROUP BY A.pay_term_id;
   
   BEGIN
   
      FOR rec_ IN get_list_notifications LOOP
   
         l_clob_request := '{ "paymentConditions": [';
         FOR rec_cod_pgto_ IN get_cod_pgto (rec_.code) LOOP
             IF l_clob_request <> '{ "paymentConditions": [' THEN 
                l_clob_request := l_clob_request || ',';
             END IF;
             l_clob_request := l_clob_request || '{';
             l_clob_request := l_clob_request || '"external_id": "' || rec_cod_pgto_.condition_||'",';              
             l_clob_request := l_clob_request || '"is_default": ' || rec_cod_pgto_.default_||',';
             l_clob_request := l_clob_request || '"condition": "' || rec_cod_pgto_.condition_||'",';
             l_clob_request := l_clob_request || '"is_active": 1,';
             l_clob_request := l_clob_request || '"due_date": '   || rec_cod_pgto_.prazo_medio_;
             l_clob_request := l_clob_request || '}';
         END LOOP;  
         l_clob_request := l_clob_request || ']}';
   
         -- dbms_output.put_line('--------------request--------');
          dbms_output.put_line(l_clob_request);
   
         endPoint_ := '/rest/consumer_maxprint/V1/paymentConditions';    
         Execute_Json(token_, host_name_, endPoint_, 'POST', l_clob_request, l_clob_response, error_);
   
         -- dbms_output.put_line('--------------response--------');
         -- dbms_output.put_line(error_);
   
         IF error_ = 'FALSE' THEN
            Atualizar_Notificacao(rec_.id);
   
         ELSE
            Gravar_Log_Trigger(USER,  'ERROR Execute_Condicao_Pagamento: '||substr(l_clob_response,1,1600));           
            Enviar_Email('ERROR Execute_Condicao_Pagamento: '||substr(l_clob_response,1,1600),'Magento Consumer - Erro - Cadastro Condicao Pagamento');
         END IF;
   
         COMMIT;
      END LOOP;       
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Condicao_Pagamento');
   Cust(token_, host_name_);
END Execute_Condicao_Pagamento;


PROCEDURE Execute_Json( token_           IN VARCHAR2,
                        host_name_       IN VARCHAR2, 
                        endPoint_        IN VARCHAR2 , 
                        method_          IN VARCHAR2, 
                        l_clob_request_  IN  CLOB, 
                        l_clob_response_ OUT CLOB, 
                        status_erro_     OUT VARCHAR2)
IS
   
   PROCEDURE Cust( token_           IN VARCHAR2,
                           host_name_       IN VARCHAR2, 
                           endPoint_        IN VARCHAR2 , 
                           method_          IN VARCHAR2, 
                           l_clob_request_  IN  CLOB, 
                           l_clob_response_ OUT CLOB, 
                           status_erro_     OUT VARCHAR2)
   IS
      l_http_request   UTL_HTTP.req;
      l_http_response  UTL_HTTP.resp;
      l_clob_response  CLOB;
      l_clob_request   CLOB;
      bufferY          VARCHAR2(2000);
      amount           pls_integer:=2000;
      offset           pls_integer:=1;
      buffer           VARCHAR2(4000);
      l_raw_data       RAW (512);
      req_length       binary_integer;
      l_buffer_size    NUMBER (10)      := 512;
      error_           VARCHAR2(5);
   
   BEGIN
      l_clob_request := l_clob_request_;                   
   
      l_http_request := NULL;
      l_http_request :=  UTL_HTTP.begin_request (url             => 'https://' || host_name_ || endPoint_,
                                                   method        => method_,
                                                   http_version  => 'HTTP/1.1'
                                                  );
   
      utl_http.set_header(l_http_request, 'Authorization', 'Bearer ' || token_); 
      utl_http.set_header(l_http_request, 'Accept', 'application/json'); 
      utl_http.set_header(l_http_request, 'Content-Type', 'application/json'); 
      IF UPPER(method_) IN ('POST','PUT') THEN
         utl_http.set_header(l_http_request, 'Content-Length', length(l_clob_request_));
      END IF;
   
      req_length := DBMS_LOB.getlength (l_clob_request_);
      offset :=1;
      bufferY :=null;
      amount:=2000;
   
      WHILE (offset < req_length) LOOP
        DBMS_LOB.read (l_clob_request_,
                       amount,
                       offset,
                       bufferY);
        UTL_HTTP.write_text (l_http_request, bufferY);
        offset := offset + amount;
      END LOOP; 
   
      BEGIN
          l_http_response := UTL_HTTP.get_response (l_http_request); 
          l_clob_response :=null;
   
          error_ := 'FALSE';
          IF l_http_response.status_code <> 200 THEN
              error_ := 'TRUE';
          END IF;
   
          BEGIN   
              <<response_loop>>
              LOOP
                  UTL_HTTP.read_raw (l_http_response, l_raw_data, l_buffer_size);
                  l_clob_response := l_clob_response || UTL_RAW.cast_to_varchar2 (l_raw_data);
              END LOOP response_loop;
          EXCEPTION
          WHEN UTL_HTTP.end_of_body THEN
               UTL_HTTP.end_response (l_http_response);
          END;
      EXCEPTION
         WHEN OTHERS THEN
             error_ := 'TRUE';
             l_clob_response := SQLERRM;
      END;
   
      IF l_http_request.private_hndl IS NOT NULL THEN
          UTL_HTTP.end_request (l_http_request);
      END IF;
   
      IF l_http_response.private_hndl IS NOT NULL THEN
          UTL_HTTP.end_response (l_http_response);
      END IF;
   
      status_erro_      := error_;   
      l_clob_response_  := l_clob_response;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Json');
   Cust(token_, host_name_, endPoint_, method_, l_clob_request_, l_clob_response_, status_erro_);
END Execute_Json;


FUNCTION convertToUnicode(text_ VARCHAR2)  RETURN VARCHAR2
IS
   
   FUNCTION Cust(text_ VARCHAR2)  RETURN VARCHAR2
   IS 
      unicode_text_  VARCHAR2(4000);
   BEGIN
   
      unicode_text_ := REPLACE(text_, CHR(161 using nchar_cs), '\u00a1');
      unicode_text_ := REPLACE(unicode_text_, CHR(162 using nchar_cs), '\u00a2');/*'Â¢'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(163 using nchar_cs), '\u00a3');/*'Â£'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(164 using nchar_cs), '\u00a4');/*'Â¤'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(165 using nchar_cs), '\u00a5');/*'Â¥'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(166 using nchar_cs), '\u00a6');/*'Â¦'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(167 using nchar_cs), '\u00a7');/*'Â§'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(168 using nchar_cs), '\u00a8');/*'Â¨'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(169 using nchar_cs), '\u00a9');/*'Â©'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(170 using nchar_cs), '\u00aa');/*'Âª'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(171 using nchar_cs), '\u00ab');/*'Â«'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(172 using nchar_cs), '\u00ac');/*'Â¬'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(173 using nchar_cs), '\u00ad');/*'Â­'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(45 using nchar_cs), '\u00ad');/*'Â­'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(174 using nchar_cs), '\u00ae');/*'Â®'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(175 using nchar_cs), '\u00af');/*'Â¯'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(176 using nchar_cs), '\u00b0');/*'Â°'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(177 using nchar_cs), '\u00b1');/*'Â±'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(178 using nchar_cs), '\u00b2');/*'Â²'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(179 using nchar_cs), '\u00b3');/*'Â³'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(180 using nchar_cs), '\u00b4');/*'Â´'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(181 using nchar_cs), '\u00b5');/*'Âµ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(182 using nchar_cs), '\u00b6');/*'Â¶'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(183 using nchar_cs), '\u00b7');/*'Â·'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(184 using nchar_cs), '\u00b8');/*'Â¸'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(185 using nchar_cs), '\u00b9');/*'Â¹'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(186 using nchar_cs), '\u00ba');/*'Âº'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(187 using nchar_cs), '\u00bb');/*'Â»'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(188 using nchar_cs), '\u00bc');/*'Â¼'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(189 using nchar_cs), '\u00bd');/*'Â½'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(190 using nchar_cs), '\u00be');/*'Â¾'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(191 using nchar_cs), '\u00bf');/*'Â¿'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(192 using nchar_cs), '\u00c0');/*'A€'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(193 using nchar_cs), '\u00c1');/*'A?'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(194 using nchar_cs), '\u00c2');/*'A‚'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(195 using nchar_cs), '\u00c3');/*'Aƒ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(196 using nchar_cs), '\u00c4');/*'A„'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(197 using nchar_cs), '\u00c5');/*'A…'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(198 using nchar_cs), '\u00c6');/*'A†'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(199 using nchar_cs), '\u00c7');/*'A‡'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(200 using nchar_cs), '\u00c8');/*'Aˆ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(201 using nchar_cs), '\u00c9');/*'A‰'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(202 using nchar_cs), '\u00ca');/*'AŠ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(203 using nchar_cs), '\u00cb');/*'A‹'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(204 using nchar_cs), '\u00cc');/*'AŒ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(205 using nchar_cs), '\u00cd');/*'A?'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(206 using nchar_cs), '\u00ce');/*'AŽ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(207 using nchar_cs), '\u00cf');/*'A?'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(208 using nchar_cs), '\u00d0');/*'A?'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(209 using nchar_cs), '\u00d1');/*'A‘'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(210 using nchar_cs), '\u00d2');/*'A’'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(211 using nchar_cs), '\u00d3');/*'A“'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(212 using nchar_cs), '\u00d4');/*'A”'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(213 using nchar_cs), '\u00d5');/*'A•'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(214 using nchar_cs), '\u00d6');/*'A–'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(215 using nchar_cs), '\u00d7');/*'A—'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(216 using nchar_cs), '\u00d8');/*'A˜'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(217 using nchar_cs), '\u00d9');/*'A™'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(218 using nchar_cs), '\u00da');/*'Aš'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(219 using nchar_cs), '\u00db');/*'A›'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(220 using nchar_cs), '\u00dc');/*'Aœ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(221 using nchar_cs), '\u00dd');/*'A?'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(222 using nchar_cs), '\u00de');/*'Až'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(223 using nchar_cs), '\u00df');/*'AŸ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(224 using nchar_cs), '\u00e0');/*'A '*/
      unicode_text_ := REPLACE(unicode_text_, CHR(225 using nchar_cs), '\u00e1');/*'A¡'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(226 using nchar_cs), '\u00e2');/*'A¢'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(227 using nchar_cs), '\u00e3');/*'A£'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(228 using nchar_cs), '\u00e4');/*'A¤'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(229 using nchar_cs), '\u00e5');/*'A¥'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(230 using nchar_cs), '\u00e6');/*'A¦'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(231 using nchar_cs), '\u00e7');/*'A§'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(232 using nchar_cs), '\u00e8');/*'A¨'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(233 using nchar_cs), '\u00e9');/*'A©'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(234 using nchar_cs), '\u00ea');/*'Aª'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(235 using nchar_cs), '\u00eb');/*'A«'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(236 using nchar_cs), '\u00ec');/*'A¬'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(237 using nchar_cs), '\u00ed');/*'A­'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(238 using nchar_cs), '\u00ee');/*'A®'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(239 using nchar_cs), '\u00ef');/*'A¯'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(240 using nchar_cs), '\u00f0');/*'A°'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(241 using nchar_cs), '\u00f1');/*'A±'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(242 using nchar_cs), '\u00f2');/*'A²'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(243 using nchar_cs), '\u00f3');/*'A³'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(244 using nchar_cs), '\u00f4');/*'A´'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(245 using nchar_cs), '\u00f5');/*'Aµ'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(246 using nchar_cs), '\u00f6');/*'A¶'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(247 using nchar_cs), '\u00f7');/*'A·'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(248 using nchar_cs), '\u00f8');/*'A¸'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(249 using nchar_cs), '\u00f9');/*'A¹'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(250 using nchar_cs), '\u00fa');/*'Aº'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(251 using nchar_cs), '\u00fb');/*'A»'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(252 using nchar_cs), '\u00fc');/*'A¼'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(253 using nchar_cs), '\u00fd');/*'A½'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(254 using nchar_cs), '\u00fe');/*'A¾'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(255 using nchar_cs), '\u00ff');/*'A¿'*/
      unicode_text_ := REPLACE(unicode_text_, CHR(34 using nchar_cs), '\u02ba');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(47 using nchar_cs), '\u002f');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(91 using nchar_cs), '\u005b');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(93 using nchar_cs), '\u005d');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(58 using nchar_cs), '\u003a');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(126 using nchar_cs), '\u007e');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(44 using nchar_cs), '\u002c');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(46 using nchar_cs), '\u002e');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(124 using nchar_cs), '\u007c');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14844051), '\u002d');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14844056), '\u0027');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14844057), '\u0027');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14844061), '\u0022');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14846372), '\u2264');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(52905), '\u03A9');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14845094), '\u2126');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14844066), '\u2022');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(15049643), '\u58EB');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(15711373), '\uFF0D');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(50050), '\u00C2');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(53126), '\u03C6');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14846374), '\u2266');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14846375), '\u2267');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(15711365), '\uFF05');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(14846373), '\u2265');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(40), '\u0028');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(41), '\u0029');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(59), '\u003B');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(53392), '\u0410');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(37 using nchar_cs), '\u0025');/*'A¿'teste*/
      unicode_text_ := REPLACE(unicode_text_, CHR(10 using nchar_cs), '\n<p>');/*new line*/
      unicode_text_ := REPLACE(unicode_text_, CHR(13 using nchar_cs), '<\/p>\r');/*carriage return*/
      unicode_text_ := REPLACE(unicode_text_, CHR(8482 using nchar_cs), '\u2122');/*™*/
      unicode_text_ := REPLACE(unicode_text_, CHR(632 using nchar_cs), '\u0278');--?
      unicode_text_ := REPLACE(unicode_text_, CHR(934 using nchar_cs), '\u03a6');--F
      unicode_text_ := REPLACE(unicode_text_, CHR(160 using nchar_cs), CHR(32 using nchar_cs));--?
      unicode_text_ := REPLACE(unicode_text_, CHR(9), '\u0020'); -- tab horizontal substituir por espaco
      unicode_text_ := REPLACE(unicode_text_, CHR(13), '\u0020'); -- CARRIGE RETURN substituir por espaco
      unicode_text_ := REPLACE(unicode_text_, CHR(10), '\u0020'); -- tLINE FEED substituir por espaco
   
      RETURN unicode_text_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'convertToUnicode');
   RETURN Cust(text_);
END convertToUnicode;


FUNCTION Tira_Acentos ( texto_ IN VARCHAR2 ) RETURN VARCHAR2
IS
   
   FUNCTION Cust ( texto_ IN VARCHAR2 ) RETURN VARCHAR2
   IS
   
      temp_text_ VARCHAR2(2000);
   
   BEGIN
   
      temp_text_ := texto_;
      temp_text_ := replace(temp_text_,UNISTR('\00C0'),'A'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C1'),'A'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C2'),'A'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C3'),'A'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C4'),'A'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C5'),'A'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C6'),'A'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C7'),'C'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C8'),'E'); 
      temp_text_ := replace(temp_text_,UNISTR('\00C9'),'E'); 
      temp_text_ := replace(temp_text_,UNISTR('\00CA'),'E'); 
      temp_text_ := replace(temp_text_,UNISTR('\00CB'),'E'); 
      temp_text_ := replace(temp_text_,UNISTR('\00CC'),'I'); 
      temp_text_ := replace(temp_text_,UNISTR('\00CD'),'I'); 
      temp_text_ := replace(temp_text_,UNISTR('\00CE'),'I'); 
      temp_text_ := replace(temp_text_,UNISTR('\00CF'),'I'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D0'),'D'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D1'),'N'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D2'),'O'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D3'),'O'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D4'),'O'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D5'),'O'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D6'),'O'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D7'),'x'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D8'),'O'); 
      temp_text_ := replace(temp_text_,UNISTR('\00D9'),'U'); 
      temp_text_ := replace(temp_text_,UNISTR('\00DA'),'U'); 
      temp_text_ := replace(temp_text_,UNISTR('\00DB'),'U'); 
      temp_text_ := replace(temp_text_,UNISTR('\00DC'),'U'); 
      temp_text_ := replace(temp_text_,UNISTR('\00DD'),'Y'); 
      temp_text_ := replace(temp_text_,UNISTR('\00DF'),'B'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E0'),'a'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E1'),'a'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E2'),'a'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E3'),'a'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E4'),'a'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E5'),'a'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E6'),'a'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E7'),'c'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E8'),'e'); 
      temp_text_ := replace(temp_text_,UNISTR('\00E9'),'e'); 
      temp_text_ := replace(temp_text_,UNISTR('\00EA'),'e'); 
      temp_text_ := replace(temp_text_,UNISTR('\00EB'),'e'); 
      temp_text_ := replace(temp_text_,UNISTR('\00EC'),'i'); 
      temp_text_ := replace(temp_text_,UNISTR('\00ED'),'i'); 
      temp_text_ := replace(temp_text_,UNISTR('\00EE'),'i'); 
      temp_text_ := replace(temp_text_,UNISTR('\00EF'),'i'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F0'),'d'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F1'),'n'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F2'),'o'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F3'),'o'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F4'),'o'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F5'),'o'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F6'),'o'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F7'),'/'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F9'),'u'); 
      temp_text_ := replace(temp_text_,UNISTR('\00FA'),'u'); 
      temp_text_ := replace(temp_text_,UNISTR('\00FB'),'u'); 
      temp_text_ := replace(temp_text_,UNISTR('\00FC'),'u'); 
      temp_text_ := replace(temp_text_,UNISTR('\00FD'),'y'); 
      temp_text_ := replace(temp_text_,UNISTR('\00FF'),'y'); 
      temp_text_ := replace(temp_text_,UNISTR('\0153'),'o'); 
      temp_text_ := replace(temp_text_,UNISTR('\2039'),'<'); 
      temp_text_ := replace(temp_text_,UNISTR('\203A'),'>'); 
      temp_text_ := replace(temp_text_,UNISTR('\00AB'),'<'); 
      temp_text_ := replace(temp_text_,UNISTR('\00BB'),'>'); 
      temp_text_ := replace(temp_text_,UNISTR('\00AE'),'r'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A9'),'c');  
      temp_text_ := replace(temp_text_,UNISTR('\0161'),'s'); 
      temp_text_ := replace(temp_text_,UNISTR('\017E'),'z'); 
      temp_text_ := replace(temp_text_,UNISTR('\0178'),'Y'); 
      temp_text_ := replace(temp_text_,UNISTR('\00B9'),'1'); 
      temp_text_ := replace(temp_text_,UNISTR('\00B2'),'2'); 
      temp_text_ := replace(temp_text_,UNISTR('\00B3'),'3'); 
      temp_text_ := replace(temp_text_,UNISTR('\00B5'),'u'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A7'),'S'); 
      temp_text_ := replace(temp_text_,UNISTR('\0160'),'S'); 
      temp_text_ := replace(temp_text_,UNISTR('\0192'),'f'); 
      temp_text_ := replace(temp_text_,UNISTR('\0152'),'E'); 
      temp_text_ := replace(temp_text_,UNISTR('\017D'),'Z'); 
      /*
      temp_text_ := replace(temp_text_,UNISTR('\20AC'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\2020'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\2021'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\02C6'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\2030'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\02DC'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\2122'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A1'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A2'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A3'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A4'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A5'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A6'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00A8'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00AA'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00B0'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00B1'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\2022'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00B8'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00BA'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00BC'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00BD'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00BE'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00DE'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00F8'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00FE'),'#'); 
      temp_text_ := replace(temp_text_,UNISTR('\00BF'),'#'); 
      */
      RETURN temp_text_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Tira_Acentos');
   RETURN Cust(texto_);
END Tira_Acentos;


FUNCTION get_lista_preco_ativa (lista_preco_ VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (lista_preco_ VARCHAR2) RETURN VARCHAR2
   IS
   
      lista_ativa_ VARCHAR2(1);
   
   BEGIN
   
      lista_ativa_ := 'N';
   
      IF lista_preco_ IN ('LI7','OS2','LIS','LI2','I10','I17','VA2','VA7','VAI','VAS','VL7','L07','L7S','L12','L18','L17','D07','D12','D18','D7S','DI10','DI17','DI2','DI7','DIS','DOS2') THEN
         lista_ativa_ := 'S';
      END IF;
   
      RETURN lista_ativa_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_lista_preco_ativa');
   RETURN Cust(lista_preco_);
END get_lista_preco_ativa;


FUNCTION get_operacao_fiscal (customer_id_ IN VARCHAR2, site_estoque_ IN VARCHAR2, site_venda_ IN VARCHAR2, lista_preco_ IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (customer_id_ IN VARCHAR2, site_estoque_ IN VARCHAR2, site_venda_ IN VARCHAR2, lista_preco_ IN VARCHAR2) RETURN NUMBER
   IS
   
      id_operacao_fiscal   C_PRICE_LIST_AVAIL_WEB.operation_id%TYPE;
      CURSOR get_operacao_fiscal (customer_id__ IN VARCHAR2,
                                  site_estoque__ IN VARCHAR2,
                                  site_venda__ IN VARCHAR2,
                                  lista_preco__ IN VARCHAR2) IS SELECT a.operation_id 
                                                                FROM C_PRICE_LIST_AVAIL_WEB a
                                                                WHERE a.division_id = 'M'
                                                                      AND a.customer_id = customer_id__
                                                                      -- AND a.add_to_sales_center = 'TRUE'
                                                                      AND a.price_list_no = lista_preco__
                                                                      AND a.deposit_id = site_estoque__
                                                                      AND a.operation_type = site_venda__;
   BEGIN
      id_operacao_fiscal := 0;  
      OPEN get_operacao_fiscal(customer_id_, site_estoque_, site_venda_, lista_preco_ );
      FETCH get_operacao_fiscal INTO id_operacao_fiscal;
      CLOSE get_operacao_fiscal;
   
      RETURN id_operacao_fiscal;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_operacao_fiscal');
   RETURN Cust(customer_id_, site_estoque_, site_venda_, lista_preco_);
END get_operacao_fiscal;


FUNCTION get_existe_cliente_ativo_cart (idCliente_ VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (idCliente_ VARCHAR2) RETURN VARCHAR2
   IS
      
      carteiraExiste_ VARCHAR2(1);
   
      CURSOR get_carteira (idCliente__ NVARCHAR2) IS SELECT CASE WHEN C_Customer_Portfolio_API.Get_Add_To_Sales_Center(a.vendor_id) = 'TRUE' 
                                                            THEN 'S' ELSE 'N' END flag_carteira_
                                                     FROM C_Custumers_Port a
                                                     WHERE 
                                                          a.COMPANY = 'RIO BRANCO'
                                                          AND a.BUSINESS_UNIT IN ('MAXPRINT') --('MAXPRINT', 'BOBINAS', 'PROVEDOR')
                                                          AND a.PORTFOLIO_DEFAULT = 'TRUE'
                                                          AND a.customer_id = idCliente__;
   
   BEGIN
   
      carteiraExiste_ := 'N';
   
      OPEN  get_carteira(idCliente_);
      FETCH get_carteira INTO carteiraExiste_;
      CLOSE get_carteira;
   
      carteiraExiste_ := NVL(carteiraExiste_,'N');
      RETURN carteiraExiste_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_existe_cliente_ativo_cart');
   RETURN Cust(idCliente_);
END get_existe_cliente_ativo_cart;


FUNCTION get_existe_prod_lista_preco (codigoProduto_ VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (codigoProduto_ VARCHAR2) RETURN VARCHAR2
   IS
   
      existeProduto_ VARCHAR2(1);
   
      CURSOR get_produto_lista (codigoProduto__ VARCHAR2) IS SELECT CASE WHEN COUNT(*) > 0 THEN 'S' ELSE 'N' END AS existe_produto
                                                             FROM SALES_PRICE_LIST_PART a
                                                             WHERE  a.price_list_no IN ('LI7','OS2','LIS','LI2','I10','I17','VA2','VA7','VAI','VAS','VL7','L07','L7S','L12','L18','L17','D07','D12','D18','D7S','DI10','DI17','DI2','DI7','DIS','DOS2')
                                                                    AND a.catalog_no = codigoProduto__
                                                                    AND a.sales_price > 0
                                                                    AND a.valid_from_date = (SELECT MAX(b.valid_from_date) 
                                                                                             FROM sales_price_list_part b
                                                                                             WHERE b.price_list_no = a.price_list_no 
                                                                                                   AND b.catalog_no = a.catalog_no 
                                                                                                    AND b.MIN_QUANTITY = a.MIN_QUANTITY
                                                                                                    AND b.MIN_DURATION = a.MIN_DURATION
                                                                                                    AND b.VALID_FROM_DATE <= SYSDATE
                                                                                                   AND b.objstate = 'Active');
   
   BEGIN
      existeProduto_ := 'N';
   
      OPEN  get_produto_lista(codigoProduto_);
      FETCH get_produto_lista INTO existeProduto_;
      CLOSE get_produto_lista;
   
      RETURN existeProduto_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_existe_prod_lista_preco');
   RETURN Cust(codigoProduto_);
END get_existe_prod_lista_preco;


FUNCTION get_existe_notificacao (code_ VARCHAR2, entity_ VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (code_ VARCHAR2, entity_ VARCHAR2) RETURN VARCHAR2
   IS
      
      exist_notificacao_       VARCHAR2(1);
   
      CURSOR get_existe_reg_notificacao (code__ IN VARCHAR2, 
                                         entity__ IN VARCHAR2) IS 
                                                                  SELECT CASE WHEN COUNT(*) > 0 THEN 'S' ELSE 'N' END  AS exite_notificacao
                                                                  FROM C_MAGENTO_PV_CONSUMER_ACT a
                                                                  WHERE NVL(a.TIMESTAMP,'') IS NULL
                                                                        AND a.code  = code__
                                                                        AND a.entity = entity__;
   
   BEGIN
   
      exist_notificacao_ := 'N';
   
      OPEN  get_existe_reg_notificacao(code_,entity_);
      FETCH get_existe_reg_notificacao INTO exist_notificacao_;
      CLOSE get_existe_reg_notificacao;
   
      RETURN exist_notificacao_;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_existe_notificacao');
   RETURN Cust(code_, entity_);
END get_existe_notificacao;


PROCEDURE Gravar_Notificacao(user_ IN VARCHAR2, code_ IN VARCHAR2, entity_ IN VARCHAR2, operacao_ IN VARCHAR2)
IS
   
   PROCEDURE Cust(user_ IN VARCHAR2, code_ IN VARCHAR2, entity_ IN VARCHAR2, operacao_ IN VARCHAR2)
   IS
      
   
      attr_       VARCHAR2(2000);
      objid_      VARCHAR2(2000);
      objversion_ VARCHAR2(2000);
      info_       VARCHAR2(2000);
   
   BEGIN
      IF get_existe_notificacao(code_, entity_) = 'N' THEN 
   
         Client_Sys.Clear_Attr( attr_ );
         Client_Sys.Add_To_Attr( 'ID', C_MAGENTO_PV_CONSUMER_ACT_SEQ.NEXTVAL, attr_ );
         Client_Sys.Add_To_Attr( 'USER_ID', USER, attr_ );
         Client_Sys.Add_To_Attr( 'CODE', code_, attr_ );
         Client_Sys.Add_To_Attr( 'ENTITY', entity_ , attr_ );
         Client_Sys.Add_To_Attr( 'OPERATION', operacao_, attr_ );
         Client_Sys.Add_To_Attr( 'TIMESTAMP_CREATION', SYSDATE, attr_ );
         C_MAGENTO_PV_CONSUMER_ACT_API.New__ ( info_, objid_, objversion_, attr_, 'DO');
      END IF;   
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Gravar_Notificacao');
   Cust(user_, code_, entity_, operacao_);
END Gravar_Notificacao;


PROCEDURE Gravar_Log_Trigger (user_ IN VARCHAR2,  msg_ IN VARCHAR)
IS
   
   PROCEDURE Cust (user_ IN VARCHAR2,  msg_ IN VARCHAR)
   IS
   
      attr_       VARCHAR2(2000);
      objid_      VARCHAR2(2000);
      objversion_ VARCHAR2(2000);
      info_       VARCHAR2(2000);
   
   BEGIN
   
      Client_Sys.Clear_Attr( attr_ );
      Client_Sys.Add_To_Attr( 'ID', CMagentoPVConsumerLogSeq.Nextval, attr_ );
      Client_Sys.Add_To_Attr( 'MESSAGE_ERROR', msg_ , attr_ );
      Client_Sys.Add_To_Attr( 'USER_ID', user_, attr_ );
      Client_Sys.Add_To_Attr( 'TIMESTAMP_CREATION', SYSDATE, attr_ );
      C_MAGENTO_PV_CONSUMER_LOG_API.New__ ( info_, objid_, objversion_, attr_, 'DO'  );
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Gravar_Log_Trigger');
   Cust(user_, msg_);
END Gravar_Log_Trigger;


FUNCTION get_existe_prod_mat_imposto (codigoProduto_ VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (codigoProduto_ VARCHAR2) RETURN VARCHAR2
   IS
      existeProduto_ VARCHAR2(1);
   
      CURSOR get_produto (codigoProduto__ VARCHAR2) IS SELECT CASE WHEN COUNT(*) > 0 THEN 'S' ELSE 'N' END AS existe_produto
                                                       FROM TAX_PART a 
                                                       WHERE a.FISCAL_PART_TYPE_DB = 2 
                                                             AND a.contract = 'SC19M' 
                                                             AND a.part_no = codigoProduto__;
   
   BEGIN
      existeProduto_ := 'N';
   
      OPEN  get_produto(codigoProduto_);
      FETCH get_produto INTO existeProduto_;
      CLOSE get_produto;
   
      RETURN existeProduto_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_existe_prod_mat_imposto');
   RETURN Cust(codigoProduto_);
END get_existe_prod_mat_imposto;


PROCEDURE get_info_rio_branco( site_ IN VARCHAR2,
                               cnpj_ OUT VARCHAR2,
                               ie_ OUT VARCHAR2,
                               razao_social_ OUT VARCHAR2,
                               uf_ OUT VARCHAR2,
                               cidade_ OUT VARCHAR2,
                               cep_ OUT VARCHAR2,
                               endereco_01_ OUT VARCHAR2,
                               endereco_02_ OUT VARCHAR2,
                               bairro_ OUT VARCHAR2,
                               telefone_01_ OUT VARCHAR2,
                               telefone_02_ OUT VARCHAR2)
IS
   
   PROCEDURE Cust( site_ IN VARCHAR2,
                                  cnpj_ OUT VARCHAR2,
                                  ie_ OUT VARCHAR2,
                                  razao_social_ OUT VARCHAR2,
                                  uf_ OUT VARCHAR2,
                                  cidade_ OUT VARCHAR2,
                                  cep_ OUT VARCHAR2,
                                  endereco_01_ OUT VARCHAR2,
                                  endereco_02_ OUT VARCHAR2,
                                  bairro_ OUT VARCHAR2,
                                  telefone_01_ OUT VARCHAR2,
                                  telefone_02_ OUT VARCHAR2)
   IS
   
   BEGIN
   
      telefone_01_ :=  'SP Capital e Grande SP: 11-3738-5700';
      telefone_02_ :=  'Demais localidades: 0800 139 455';
   
      CASE 
         WHEN site_ = 'MG09M' THEN
            cnpj_ :=  '50.596.790/0009-45';
            ie_ :=  '251663554.00-03';
            razao_social_ :=  'RIO BRANCO COMERCIO E INDUSTRIA DE PAPEIS LTDA';
            uf_ :=  'MG';
            cidade_ :=  'EXTREMA';
            cep_ :=  '37640-000';
            endereco_01_ :=  'EST VER JOSE L DE OLIVEIRA, 1147';
            endereco_02_ :=  ' ';
            bairro_ :=  'RODEIO';
   
         WHEN site_ = 'PE15M' THEN
            cnpj_ :=  '50.596.790/0015-93';
            ie_ :=  '0356969-15';
            razao_social_ :=  'RIO BRANCO COMERCIO E INDUSTRIA DE PAPEIS LTDA';
            uf_ :=  'PE';
            cidade_ :=  'JABOATAO DOS GUARARAPES';
            cep_ :=  '54325-610';
            endereco_01_ :=  'RUA JOSE ALVES BEZERRA, 465';
            endereco_02_ :=  'GP E';
            bairro_ :=  'PRAZERES';
   
         WHEN site_ = 'PR16M' THEN
            cnpj_ :=  '50.596.790/0016-74';
            ie_ :=  '90418452-76';
            razao_social_ :=  'RIO BRANCO COMERCIO E INDUSTRIA DE PAPEIS LTDA';
            uf_ :=  'PR';
            cidade_ :=  'CURITIBA';
            cep_ :=  '81630-230';
            endereco_01_ :=  'RUA SAO BENTO, 2275';
            endereco_02_ :=  ' ';
            bairro_ :=  'HAUER';
   
         WHEN site_ = 'SC19M' THEN
            cnpj_ :=  '50.596.790/0019-17';
            ie_ :=  '257042369';
            razao_social_ :=  'RIO BRANCO COMERCIO E INDUSTRIA DE PAPEIS LTDA';
            uf_ :=  'SC';
            cidade_ :=  'ITAJAI';
            cep_ :=  '88316-000';
            endereco_01_ :=  'RODOVIA ANTONIO HEIL, 1001';
            endereco_02_ :=  'GALPAO 01 MODULOS 020304 E';
            bairro_ :=  'ITAIPAVA';
   
         WHEN site_ = 'SP11M' THEN
            cnpj_ :=  '50.596.790/0011-60';
            ie_ :=  '110008478113';
            razao_social_ :=  'RIO BRANCO COMERCIO E INDUSTRIA DE PAPEIS LTDA';
            uf_ :=  'SP';
            cidade_ :=  'SAO PAULO';
            cep_ :=  '03109-001';
            endereco_01_ :=  'AV HENRY FORD, 2040';
            endereco_02_ :=  ' ';
            bairro_ :=  'PARQUE MOOCA';
            telefone_01_ :=  'SP Capital e Grande SP: 11-3738-5700';
            telefone_02_ :=  'Demais localidades: 0800 139 455';
      END CASE;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_info_rio_branco');
   Cust(site_, cnpj_, ie_, razao_social_, uf_, cidade_, cep_, endereco_01_, endereco_02_, bairro_, telefone_01_, telefone_02_);
END get_info_rio_branco;


FUNCTION get_site (id_produto_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (id_produto_ IN VARCHAR2) RETURN VARCHAR2
   IS
      
   
   site_ inventory_part.contract%TYPE;
   
   CURSOR get_site (id_produto__ IN VARCHAR2 ) IS
                                                   SELECT
                                                      a.contract
                                                   FROM  INVENTORY_PART A 
                                                   WHERE A.part_no = id_produto__
                                                   AND (A.CONTRACT LIKE '%M' OR A.contract LIKE '%P' OR A.contract LIKE '%B')
                                                   AND A.PART_STATUS  = 'A'
                                                   FETCH NEXT 1 ROWS ONLY;
   BEGIN
      OPEN get_site(id_produto_);
      FETCH get_site INTO site_;
      CLOSE get_site;
   
      RETURN site_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_site');
   RETURN Cust(id_produto_);
END get_site;


PROCEDURE Atualizar_Notificacao (id_notificacao_ IN NUMBER)
IS
   
   PROCEDURE Cust (id_notificacao_ IN NUMBER)
   IS
   
      attr_           VARCHAR2(2000);
      objid_          C_MAGENTO_PV_CONSUMER_ACT.objid%TYPE;
      objversion_     C_MAGENTO_PV_CONSUMER_ACT.objversion%TYPE;
      info_           VARCHAR2(2000);
   
     CURSOR get_data(id_ IN NUMBER) IS
                                    SELECT objid,
                                           objversion
                                    FROM   C_MAGENTO_PV_CONSUMER_ACT c
                                    WHERE  c.id = id_;   
   
   BEGIN
   
      Client_SYS.Clear_Attr(attr_); 
      Client_SYS.Add_To_Attr('TIMESTAMP', SYSDATE, attr_);
      OPEN  get_data(id_notificacao_);
      FETCH get_data INTO objid_, objversion_;
      IF get_data%FOUND THEN
        C_MAGENTO_PV_CONSUMER_ACT_API.Modify__(info_, objid_, objversion_, attr_, 'DO');
      END IF;   
      CLOSE get_data;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Atualizar_Notificacao');
   Cust(id_notificacao_);
END Atualizar_Notificacao;


FUNCTION get_flag_destacado (codigo_regiao_ IN VARCHAR2, total_venda_ IN NUMBER) RETURN VARCHAR2
IS
   
   FUNCTION Cust (codigo_regiao_ IN VARCHAR2, total_venda_ IN NUMBER) RETURN VARCHAR2
   IS
   
      flag_frete_ VARCHAR2(5);
   
      CURSOR get_flag (codigo_regiao__ IN VARCHAR2,
                       total_venda__ IN NUMBER) IS
                                                   SELECT CASE WHEN COUNT(*) > 0 THEN 'FALSE' ELSE 'TRUE' END flag_
                                                   FROM C_MIN_VALUE_PER_REGION_ROW
                                                   WHERE STATUS_DB = 'R'
                                                         AND REGION_CODE = codigo_regiao__
                                                         AND MINIMUM_SALE_VALUE <= total_venda__;
   BEGIN
   
      OPEN get_flag(codigo_regiao_, total_venda_);
      FETCH get_flag INTO flag_frete_;
      CLOSE get_flag;
   
      RETURN flag_frete_;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_flag_destacado');
   RETURN Cust(codigo_regiao_, total_venda_);
END get_flag_destacado;


PROCEDURE Pesquisar_codigo_localidade (cidade_ IN VARCHAR2, uf_ IN VARCHAR2, cod_ibge_regiao_ OUT VARCHAR2, cod_ibge_cidade_ OUT VARCHAR2)
IS
   
   PROCEDURE Cust (cidade_ IN VARCHAR2, uf_ IN VARCHAR2, cod_ibge_regiao_ OUT VARCHAR2, cod_ibge_cidade_ OUT VARCHAR2)
   IS
      
   
      CURSOR get_cod_localidade (cidade__ IN VARCHAR2,
                                 uf__ IN VARCHAR2) IS
                                                   SELECT b.region_code, b.city_code 
                                                   FROM  C_CITY_ROW b
                                                   WHERE b.city_name =  cidade__
                                                         AND b.sub_region_code = uf__ ;
   BEGIN
   
      OPEN get_cod_localidade(cidade_, uf_);
      FETCH get_cod_localidade INTO cod_ibge_regiao_, cod_ibge_cidade_;
      CLOSE get_cod_localidade;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Pesquisar_codigo_localidade');
   Cust(cidade_, uf_, cod_ibge_regiao_, cod_ibge_cidade_);
END Pesquisar_codigo_localidade;


PROCEDURE Pesquisar_transportadora (site_ IN VARCHAR2, cod_cidade_ IN VARCHAR2,  cod_transportadora_ OUT VARCHAR2, qtde_dias_entrega_ OUT NUMBER)
IS
   
   PROCEDURE Cust (site_ IN VARCHAR2, cod_cidade_ IN VARCHAR2,  cod_transportadora_ OUT VARCHAR2, qtde_dias_entrega_ OUT NUMBER)
   IS
   
      CURSOR get_cod_transp (site__ IN VARCHAR2,
                             cod_cidade__ IN VARCHAR2) IS
                                                   SELECT a.forwarder_id, 
                                                          NVL(a.delivery_time,0) 
                                                   FROM C_FORWARDER_INFO_LEAD_TIME a
                                                   WHERE a.contract = site__
                                                   AND a.ibge_id  = cod_cidade__
                                                   ORDER BY a.delivery_time
                                                   FETCH FIRST 1 ROWS ONLY;
   BEGIN
   
      OPEN get_cod_transp(site_, cod_cidade_);
      FETCH get_cod_transp INTO cod_transportadora_, qtde_dias_entrega_;
      CLOSE get_cod_transp;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Pesquisar_transportadora');
   Cust(site_, cod_cidade_, cod_transportadora_, qtde_dias_entrega_);
END Pesquisar_transportadora;


FUNCTION get_aliquota_ipi (cod_produto_ IN VARCHAR2, site_ IN VARCHAR2 ) RETURN NUMBER
IS
   
   FUNCTION Cust (cod_produto_ IN VARCHAR2, site_ IN VARCHAR2 ) RETURN NUMBER
   IS
   
      aliquota_ipi_ NUMBER;
   
      CURSOR get_ipi (cod_produto__ in VARCHAR2, site__ in VARCHAR2) IS SELECT 
                                                                           CASE WHEN b.acquisition_origin_db IN (1,6)
                                                                                   THEN NVL(NVL(b.ipi_percentage,NBM_API.Get_Ipi_Tax_Percent(b.nbm_id)),0)
                                                                                WHEN b.acquisition_origin_db IN (3,5,8) AND part_catalog_api.Get_C_Sales_Manufacturer_No(b.part_no) IN ('MAX','DAZ','GOT','RBB', 'REE', 'MGB', 'HUA', 'FUI', 'SUM', 'WEC', 'BPP')
                                                                                   THEN NVL(NVL(b.ipi_percentage,NBM_API.Get_Ipi_Tax_Percent(b.nbm_id)),0)   
                                                                           ELSE 0 END  AS ipi_aliquota_
                                                                        FROM TAX_PART b
                                                                        WHERE 
                                                                           COMPANY = 'RIO BRANCO'
                                                                           AND FISCAL_PART_TYPE_DB = 2
                                                                           AND PART_NO = cod_produto__
                                                                           AND b.contract = site__
                                                                        FETCH FIRST 1 ROWS ONLY;
   BEGIN
   
         OPEN get_ipi(cod_produto_, site_);
         FETCH get_ipi INTO aliquota_ipi_;
         CLOSE get_ipi;                     
   
         RETURN aliquota_ipi_;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_aliquota_ipi');
   RETURN Cust(cod_produto_, site_);
END get_aliquota_ipi;


PROCEDURE Execute_Foto(token_ IN VARCHAR2,  host_name_ IN VARCHAR2)
IS
   
   PROCEDURE Cust(token_ IN VARCHAR2,  host_name_ IN VARCHAR2)
   IS
   
      l_clob_request            CLOB;
      l_clob_response           CLOB;
      error_                    VARCHAR2(5);
      endPoint_                 VARCHAR2(100);
      ordem_foto_               VARCHAR2(1);
      codigo_produto_           PART_CATALOG.PART_NO%TYPE;
      codigo_produto_consumer_  PART_CATALOG.PART_NO%TYPE;
      id_foto_                  NUMBER;      
      id_foto_mag_              NUMBER; 
      ordem_foto_mag_           NUMBER;           
      posicao_final_            NUMBER;
      formato_image_            VARCHAR2(10);    
      nome_image_               VARCHAR2(255);
      tipo_image_               VARCHAR2(255);
      id_image_                 VARCHAR2(10);
      image_blob_               BLOB;
      desabilitado_             VARCHAR2(5);
      obj                       pljson;
      obj_valor_                pljson_value;
      obj_lista_                pljson_list;
      id_media_mag_             NUMBER;
      id_media_mag_atualizada_  NUMBER;
      atualizar_foto_           NUMBER;
   
   
      CURSOR get_list_notifications IS
                                      SELECT   ID AS id,
                                               CODE AS code,
                                               ENTITY AS entidadeIntegrador,
                                               OPERATION AS operacaoIntegrador
                                      FROM  C_MAGENTO_Pv_Consumer_ACT
                                      WHERE TIMESTAMP IS NULL AND
                                            ENTITY = 'FT'
                                      ORDER BY TIMESTAMP_CREATION;
   
   BEGIN
      FOR rec_ IN get_list_notifications LOOP
         ordem_foto_ := SUBSTR(rec_.code,1,1);
         posicao_final_ := INSTR(rec_.code,'^',3);
         codigo_produto_ := SUBSTR(rec_.code,3,(posicao_final_ - 3));
         codigo_produto_consumer_ := 'C'|| REPLACE(SUBSTR(rec_.code,3,(posicao_final_ - 3)),' ','');
         id_foto_:= SUBSTR(rec_.code,posicao_final_ + 1,length(rec_.code));
   
         IF rec_.operacaoIntegrador <> 'D' THEN
            image_blob_ := NULL;
            image_blob_ := BINARY_OBJECT_DATA_BLOCK_API.Get_Data(id_foto_, 1);
   
            IF image_blob_ IS NULL THEN
               CONTINUE;
            END IF;
   
            tipo_image_ := NULL;
   
            IF  ordem_foto_ = '1'  THEN
               tipo_image_ := '"types":["image", "small_image", "thumbnail"],';
            ELSE
               tipo_image_ := '"types":[],';   
            END IF;
   
            formato_image_ := CASE WHEN ordem_foto_ = 1 THEN  part_catalog_api.Get_Picture1_Format(codigo_produto_)
                                   WHEN ordem_foto_ = 2 THEN  part_catalog_api.Get_Picture2_Format(codigo_produto_)
                                   WHEN ordem_foto_ = 3 THEN  part_catalog_api.Get_Picture3_Format(codigo_produto_)
                                   WHEN ordem_foto_ = 4 THEN  part_catalog_api.Get_Picture4_Format(codigo_produto_)
                                   WHEN ordem_foto_ = 5 THEN  part_catalog_api.Get_Picture5_Format(codigo_produto_)
                                   WHEN ordem_foto_ = 6 THEN  part_catalog_api.Get_Picture6_Format(codigo_produto_)
                                   WHEN ordem_foto_ = 7 THEN  part_catalog_api.Get_Picture7_Format(codigo_produto_)
                                   ELSE part_catalog_api.Get_Picture8_Format(codigo_produto_) END;
   
            nome_image_ := codigo_produto_consumer_ || ordem_foto_|| TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS'); -- || '.' || formato_image_;
   
            desabilitado_ := CASE WHEN ordem_foto_ = '8' THEN 'true' ELSE 'false' END;
   
            l_clob_request := get_clob_request_foto(imagem_blob_ => image_blob_, 
                                                    tipo_imagem_ => tipo_image_, 
                                                    formato_imagem_ => formato_image_, 
                                                    nome_imagem_ => nome_image_, 
                                                    ordem_foto_ => ordem_foto_, 
                                                    desabilitado_ => desabilitado_, 
                                                    id_media_mag_ => NULL );
   
         ELSE
   
            l_clob_request := '{"entry":{ "media_type": "image", "label": "Image", "disabled": true, "types": []}}';   
   
         END IF; 
                 -- dbms_output.put_line(l_clob_request);
            IF rec_.operacaoIntegrador = 'I' THEN              
               endPoint_ := '/rest/all/V1/products/'|| codigo_produto_consumer_ ||'/media';   
               -- dbms_output.put_line(l_clob_request);
               Execute_Json(token_, host_name_, endPoint_, 'POST', l_clob_request, l_clob_response, error_);
            END IF;
   
            IF rec_.operacaoIntegrador = 'U' THEN 
               atualizar_foto_ := 1;
               l_clob_response:= get_id_media_magento(token_, host_name_,codigo_produto_consumer_, ordem_foto_  );
               IF NVL(l_clob_response,'dumMy')  <> 'dumMy' THEN
                  obj_lista_ := pljson_list(l_clob_response);
                  FOR r IN 1 .. obj_lista_.count LOOP
                     obj := pljson(obj_lista_.get(r));
                     obj_valor_ := obj.get('id');
                     id_media_mag_ := obj_valor_.get_number;
                     obj_valor_ := obj.get('position');
                     ordem_foto_mag_ := obj_valor_.get_number;
                     IF ordem_foto_mag_ = ordem_foto_  AND  atualizar_foto_ = 1 THEN
   
                        atualizar_foto_ := 0;
                        l_clob_request := get_clob_request_foto(imagem_blob_ => image_blob_, 
                                                       tipo_imagem_ => tipo_image_, 
                                                       formato_imagem_ => formato_image_, 
                                                       nome_imagem_ => nome_image_, 
                                                       ordem_foto_ => ordem_foto_, 
                                                       desabilitado_ => desabilitado_, 
                                                       id_media_mag_ => id_media_mag_ );
                        endPoint_ := '/rest/all/V1/products/'|| codigo_produto_consumer_ ||'/media/' || id_media_mag_ ;
                        Execute_Json(token_, host_name_, endPoint_, 'PUT', l_clob_request, l_clob_response, error_);                             
                        EXIT;
                     END IF;   
                  END LOOP;
               END IF;
            END IF;              
            IF rec_.operacaoIntegrador = 'D' THEN 
               l_clob_response:= get_id_media_magento(token_, host_name_,codigo_produto_consumer_, ordem_foto_  );
               IF NVL(l_clob_response,'dumMy')  <> 'dumMy' THEN
                  obj_lista_ := pljson_list(l_clob_response);
                  FOR r IN 1 .. obj_lista_.count LOOP
                     obj := pljson(obj_lista_.get(r));
                     obj_valor_ := obj.get('id');
                     id_media_mag_ := obj_valor_.get_number;
                     obj_valor_ := obj.get('position');
                     ordem_foto_mag_ := obj_valor_.get_number;   
                     IF ordem_foto_mag_ = ordem_foto_  THEN
                        Deletar_media_magento(token_, host_name_, codigo_produto_consumer_, ordem_foto_, id_media_mag_, error_ );
                     END IF;
                  END LOOP;      
               END IF;
            END IF;
   
            IF error_ = 'FALSE' THEN
               Atualizar_Notificacao(rec_.id);      
            ELSE
                Gravar_Log_Trigger(USER,  'ERROR Execute_FOTO: ' || rec_.code || ' - ' ||substr(l_clob_response,1,1600));           
                --Enviar_Email('ERROR Execute_FOTO: ' || rec_.code || ' - ' ||substr(l_clob_response,1,1600),'Magento Consumer - Erro - Cadastro Foto');
            END IF;
   
            COMMIT;
   
      END LOOP;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Foto');
   Cust(token_, host_name_);
END Execute_Foto;


FUNCTION base64encode(p_blob IN BLOB) RETURN CLOB
IS
   
   FUNCTION Cust(p_blob IN BLOB) RETURN CLOB
   IS
   
      l_clob CLOB;
      l_step PLS_INTEGER := 12000;
   
   BEGIN
   
      FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(p_blob) - 1 )/l_step) LOOP
         l_clob := l_clob || UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(DBMS_LOB.substr(p_blob, l_step, i * l_step + 1)));
      END LOOP;
   
      RETURN l_clob;
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'base64encode');
   RETURN Cust(p_blob);
END base64encode;


PROCEDURE Deletar_media_magento (token_          IN VARCHAR2,
                                 host_name_      IN VARCHAR2, 
                                 codigo_produto_ IN VARCHAR2, 
                                 ordem_produto_  IN VARCHAR2, 
                                 id_magento_     IN NUMBER, 
                                 status_erro_    OUT VARCHAR2)
IS
   
   PROCEDURE Cust (token_          IN VARCHAR2,
                                    host_name_      IN VARCHAR2, 
                                    codigo_produto_ IN VARCHAR2, 
                                    ordem_produto_  IN VARCHAR2, 
                                    id_magento_     IN NUMBER, 
                                    status_erro_    OUT VARCHAR2)
   IS
   
      l_clob_request  CLOB;
      l_clob_response CLOB;
      endPoint_       VARCHAR2(200);
      error_status_   VARCHAR2(100);
      obj             pljson;
      obj_valor_      pljson_value;
      obj_lista_      pljson_list;
      id_media_mag_   NUMBER;
      ordem_foto_mag_ NUMBER;
   
   BEGIN
   
      l_clob_request := '{"entry":{ "id": '|| id_media_mag_ ||', "media_type": "image", "label": "Image", "disabled": true, "types": []}}';    
      endPoint_:=  '/rest/consumer_maxprint/V1/products/'|| codigo_produto_ ||'/media/' || id_magento_;
      Execute_Json(token_, host_name_, endPoint_, 'PUT', l_clob_request, l_clob_response, error_status_);
      endPoint_:=  '/rest/all/V1/products/'|| codigo_produto_ ||'/media/' || id_magento_;
      Execute_Json(token_, host_name_, endPoint_, 'PUT', l_clob_request, l_clob_response, error_status_);
      endPoint_:=  '/rest/consumer_maxprint/V1/products/'|| codigo_produto_ ||'/media/' || id_magento_;
      Execute_Json(token_, host_name_, endPoint_, 'DELETE', l_clob_request, l_clob_response, error_status_);
   
      IF error_status_ <> 'FALSE' THEN
         Gravar_Log_Trigger(USER,  'ERROR Deletar_media_magento: '||substr(l_clob_response,1,1600));
      END IF;   
      status_erro_ := error_status_;
            
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Deletar_media_magento');
   Cust(token_, host_name_, codigo_produto_, ordem_produto_, id_magento_, status_erro_);
END Deletar_media_magento;


FUNCTION get_id_media_magento (token_ IN VARCHAR2, host_name_ IN VARCHAR2, codigo_produto_ IN VARCHAR2, ordem_produto_ IN VARCHAR2) RETURN CLOB
IS
   
   FUNCTION Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2, codigo_produto_ IN VARCHAR2, ordem_produto_ IN VARCHAR2) RETURN CLOB
   IS
      
      l_clob_request  CLOB;
      l_clob_response CLOB;
      endPoint_       VARCHAR2(200);
      error_status_   VARCHAR2(100);
      token__         VARCHAR2(100);
      host_name__     VARCHAR2(100);
   
   BEGIN
   
      endPoint_ :='/rest/consumer_maxprint/V1/products/'||codigo_produto_||'/media?searchCriteria[filter_groups][1][filters][0][field]=positionsearchCriteria[filter_groups][1][filters][0][value]='||ordem_produto_;
      token__ := token_;
      host_name__ := host_name_;
   
      IF NVL(token__, 'dUmMy') = 'dUmMy' THEN
         Gerar_Token(token__, host_name__);
      END IF;
   
      l_clob_request:= '';
      Execute_Json(token__, host_name__, endPoint_, 'GET', l_clob_request, l_clob_response, error_status_);
   
      IF error_status_ <> 'FALSE' THEN
         Gravar_Log_Trigger(USER,  'ERROR get_id_media_magento: '||substr(l_clob_response,1,1600));
      END IF;   
   
      RETURN l_clob_response;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_id_media_magento');
   RETURN Cust(token_, host_name_, codigo_produto_, ordem_produto_);
END get_id_media_magento;


PROCEDURE Gerar_Token (token__ OUT VARCHAR2, l_host_name__ OUT VARCHAR2)
IS
   
   PROCEDURE Cust (token__ OUT VARCHAR2, l_host_name__ OUT VARCHAR2)
   IS
   
      l_http_request     UTL_HTTP.req;
      l_http_response    UTL_HTTP.resp;
      l_host_name        VARCHAR2 (128);
      proxy_address_ VARCHAR2(1000);
      wallet_path_   VARCHAR2(1000);
      wallet_pass_   VARCHAR2(100);
      content varchar2(4000);
      buffer varchar2(4000);
      token_ VARCHAR2(1000);
   
   BEGIN
   
      l_host_name := Object_Property_API.Get_Value('MagentoConfiguration', 'Site', 'URL_HTTPS');
      content := Object_Property_API.Get_Value('MagentoConfiguration', 'Site', 'LOGIN');
      proxy_address_ := Object_Property_API.Get_Value('TrackingConfiguration', 'PROXY', 'URL');
      utl_http.set_proxy(proxy_address_);
      wallet_path_ := Object_Property_API.Get_Value('TrackingConfiguration', 'WALLET_PATH', 'WALLET_CAMINHO');
      wallet_pass_ := Object_Property_API.Get_Value('TrackingConfiguration', 'WALLET_PASS', 'WALLET_SENHA');
      UTL_HTTP.set_wallet('file:' || wallet_path_, wallet_pass_);
   
      l_http_request :=    UTL_HTTP.begin_request (url               =>    'https://' || l_host_name || '/rest/V1/integration/admin/token/',
                                                 method            => 'POST',
                                                 http_version      => 'HTTP/1.1'
                                                );
   
      utl_http.set_header(l_http_request, 'user-agent', 'mozilla/4.0'); 
      utl_http.set_header(l_http_request, 'content-type', 'application/json'); 
      utl_http.set_header(l_http_request, 'Content-Length', length(content));
      utl_http.write_text(l_http_request, content);
   
      l_http_response := UTL_HTTP.get_response (l_http_request); 
   
      BEGIN
         LOOP
            utl_http.read_line(l_http_response, buffer);
            token_ := REPLACE(buffer,'"', '');
         END LOOP;
         utl_http.end_response(l_http_response);
      EXCEPTION
         WHEN utl_http.end_of_body THEN
            utl_http.end_response(l_http_response);
      END;
      -- token e host_name do ambiente de integracao
      -- l_host_name := 'integration-5ojmyuq-n5eyx2zfsuzgs.us-5.magentosite.cloud';
      -- token_ := 'ssw1qt40sz2mfjbnofv2931lu8du3e9o';
   
      token__       := token_;
      l_host_name__ := l_host_name;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Gerar_Token');
   Cust(token__, l_host_name__);
END Gerar_Token;


PROCEDURE Execute_Ordens
IS
   
   PROCEDURE Cust
   IS
      quotation_no_                 ORDER_QUOTATION.quotation_no%TYPE;
      wanted_delivery_date_         DATE;
      c_not_highlight_freight_temp_ VARCHAR2(5);
      info_                         VARCHAR2(32000);
      objid_                        VARCHAR2(100);
      objversion_                   VARCHAR2(100);
      attr_                         VARCHAR2(32000);
      status_quotation_             ORDER_QUOTATION.objstate%TYPE;
      note_id_                      ORDER_QUOTATION.note_id%TYPE;         
      order_no_                     CUSTOMER_ORDER.order_no%TYPE;
      business_unit_                SALES_PART_SALESMAN.business_unit%TYPE;
      customer_ative_portifolio_    VARCHAR2(1);
      vendor_portifolio_default_    SALES_PART_SALESMAN.salesman_code%TYPE;
      vendor_bolsao_                SALES_PART_SALESMAN.c_bolsao_salesman%TYPE;
   
      CURSOR get_int_cotacao_header IS SELECT DISTINCT
                                          a.entity_id,
                                          a.contract_stock,
                                          a.contract_sales,
                                          a.type_order,
                                          a.inter_site_operation,
                                          a.operation_id,
                                          a.pay_term_id,
                                          a.delivery_terms,
                                          a.customer_no,
                                          a.forward_agent_id,
                                          a.salesman_attendant,
                                          a.c_not_highlight_freight,
                                          a.ship_via_code,
                                          a.bill_addr_no,
                                          a.ship_addr_no,
                                          a.obs_nf,
                                          a.obs_pedido,
                                          a.num_oc_cliente
                                       FROM C_INT_MAG_CONSUMER_ORDER_TAB a
                                       WHERE 
                                        a.id_quotation_ifs IS NULL;
   
      CURSOR get_temp_cot_item (entity_id__ NUMBER) IS SELECT 
                                                          b.price_list_no,
                                                          b.item_id,
                                                          b.sku,
                                                          b.part_no,
                                                          b.buy_qty_due,
                                                          b.sale_unit_price,
                                                          b.ipi_percentage,
                                                          b.discount_perc_calc
                                                       FROM C_INT_MAG_CONSUMER_ORDER_TAB b
                                                       WHERE b.entity_id = entity_id__;
                                                       
       CURSOR get_cot (quotation_no__ IN VARCHAR2) IS SELECT a.objid, a.objversion, a.note_id
                                                      FROM ORDER_QUOTATION a
                                                      WHERE  a.quotation_no = quotation_no__;                                               
                                                       
                            
   BEGIN
   
      FOR cot_h IN get_int_cotacao_header LOOP
         IF cot_h.salesman_attendant IN ('12458', '12456') THEN
            wanted_delivery_date_ := TO_DATE(TO_CHAR(sysdate, 'DD/MM/YYYY') || ' 23:59:59', 'DD/MM/YYYY HH24:MI:SS');
            quotation_no_ := 'CONS' || cot_h.entity_id;
            c_not_highlight_freight_temp_ := 'TRUE';
            BEGIN 
      
               business_unit_ := SALES_PART_SALESMAN_API.Get_Business_Unit(cot_h.salesman_attendant );
               customer_ative_portifolio_ := Check_carteira_cliente( cot_h.customer_no , cot_h.salesman_attendant , business_unit_);
      
               IF customer_ative_portifolio_ = 'N' THEN
                   vendor_portifolio_default_ := get_vendor_portfolio_default(cot_h.customer_no, business_unit_);
                   vendor_bolsao_ := NVL(SALES_PART_SALESMAN_API.Get_C_Bolsao_Salesman(vendor_portifolio_default_),'FALSE');
                   IF vendor_bolsao_ = 'TRUE' THEN
                      Atualizar_Carteira_Cliente(cot_h.customer_no , business_unit_, vendor_portifolio_default_, cot_h.salesman_attendant );
                   END IF;
               END IF;
      
               Create_Quotation(customer_no_ => cot_h.customer_no, 
                                   wanted_delivery_date_ => wanted_delivery_date_,
                                   contract_ => cot_h.Contract_Sales, 
                                   addr_no_ => cot_h.bill_addr_no, 
                                   forward_agent_id_ => cot_h.forward_agent_id, 
                                   operation_id_ =>  cot_h.operation_id, 
                                   pay_term_id_ => cot_h.pay_term_id, 
                                   ship_via_code_ => cot_h.ship_via_code, 
                                   c_salesman_attendant_ => cot_h.salesman_attendant, 
                                   c_inter_site_operation_ => cot_h.inter_site_operation, 
                                   c_not_highlight_freight_ => c_not_highlight_freight_temp_, 
                                   delivery_terms_          => cot_h.Delivery_Terms,
                                   num_oc_cliente_          => cot_h.num_oc_cliente,                                
                                   quotation_no_ => quotation_no_);
      
               UPDATE C_INT_MAG_CONSUMER_ORDER_TAB
               SET ID_QUOTATION_IFS = quotation_no_,
                   STATUS_ORDER_IFS = 'rb_integrated_erp'
               WHERE  entity_id = cot_h.entity_id;
      
            EXCEPTION
               WHEN OTHERS THEN
                  DBMS_OUTPUT.PUT_LINE( 'ERRO CRIAR COTACAOO MAGENTO CONSUMER - COT NO: ' || quotation_no_ || ' - CODIGO ERRO: '||SQLCODE||' ERROR DESCR: '||SQLERRM);
                  CONTINUE;
            END; 
      
            FOR cot_i IN get_temp_cot_item (cot_h.entity_id)LOOP
               BEGIN 
                  Create_Quotation_Item(quotation_no_           => quotation_no_, 
                                        catalog_no_             => cot_i.part_no, 
                                        contract_               => cot_h.Contract_Sales, 
                                        price_list_no_          => cot_i.price_list_no, 
                                        vendor_no_              => cot_h.contract_stock, 
                                        wanted_delivery_date_   =>  wanted_delivery_date_, 
                                        c_inter_site_operation_ => cot_h.inter_site_operation,
                                        forward_agent_id_       => cot_h.forward_agent_id,
                                        ipi_perc_               => cot_i.ipi_percentage,
                                        sale_unit_price_calc_   => cot_i.sale_unit_price, 
                                        discount_perc_calc_     => cot_i.discount_perc_calc,
                                        buy_qty_due_            => cot_i.buy_qty_due); 
                EXCEPTION
                  WHEN OTHERS THEN
      
                 Gravar_Log_Trigger(USER,  'ERRO CRIAR COTACAOO MAGENTO CONSUMER - COT NO: ' || quotation_no_ || '-' || cot_i.part_no  || ' - CODIGO ERRO: '||SQLCODE||' ERROR DESCR: '||SQLERRM);                             
                 -- Enviar_Email('ERRO CRIAR COTACAOO MAGENTO CONSUMER - COT NO: ' || quotation_no_ || '-' || cot_i.part_no  || ' - CODIGO ERRO: '||SQLCODE||' ERROR DESCR: '||SQLERRM);                                  
                END; 
            END LOOP;
      
            Create_Quotation_Freight(quotation_no_);
      
            IF NVL(cot_h.obs_nf,'duMMy') <> 'duMMy' THEN
               OPEN get_cot(quotation_no_);
               FETCH get_cot INTO objid_, objversion_, note_id_;
               CLOSE get_cot;
      
               info_        := NULL;
               objid_       := NULL;
               objversion_  := NULL;
               attr_        := NULL;
               client_sys.Clear_attr(attr_);
               Client_SYS.Add_To_Attr('OUTPUT_TYPE', 'NFE', attr_);
               Client_SYS.Add_To_Attr('NOTE_TEXT', cot_h.obs_nf, attr_);
               Client_SYS.Add_To_Attr('NOTE_ID', note_id_, attr_);
               IFSRIB.DOCUMENT_TEXT_API.NEW__( info_ , objid_ , objversion_ , attr_ , 'DO' );
            END IF;
      
            IF cot_h.c_not_highlight_freight = 'FALSE' THEN
               info_        := NULL;
               objid_       := NULL;
               objversion_  := NULL;
               attr_        := 'C_NOT_HIGHLIGHT_FREIGHT'||chr(31)||'FALSE'||chr(30);
      
               OPEN get_cot(quotation_no_);
               FETCH get_cot INTO objid_, objversion_, note_id_;
               CLOSE get_cot;
               IFSRIB.ORDER_QUOTATION_API.MODIFY__( info_ , objid_ , objversion_ , attr_ , 'DO' );
            END IF;
      
            BEGIN
                Create_Order(quotation_no_ => quotation_no_, 
                             lose_win_note_ => NULL, 
                             customer_po_no_ => cot_h.num_oc_cliente , 
                             fiscal_note_obs_ => NULL, 
                             reason_id_ => '007', 
                             cust_ref_ => NULL, 
                             order_no_ => order_no_);
      
                  UPDATE C_INT_MAG_CONSUMER_ORDER_TAB a
                  SET a.id_order_ifs = order_no_,
                      a.status_order_ifs = 'rb_integrated_erp'
                  WHERE  entity_id = cot_h.entity_id;            
      
               EXCEPTION
               WHEN OTHERS THEN
      
                   Gravar_Log_Trigger(USER,  'ERRO CRIAR ORDEM VENDA MAGENTO CONSUMER - COT NO: ' || quotation_no_ || ' - CODIGO ERRO: '||SQLCODE||' ERROR DESCR: '||SQLERRM);           
                 -- Enviar_Email('ERROR Execute_Produto: '|| ' PRODUTO: ' || rec_produto_.sku_ ||substr(l_clob_response,1,1600),'Magento Consumer - Erro - Cadastro Produto');                  
                  CONTINUE;
            END;
         END IF; 
      END LOOP;
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Ordens');
   Cust;
END Execute_Ordens;


FUNCTION get_ordem_magento (token_ IN VARCHAR2, host_name_ IN VARCHAR2) RETURN CLOB
IS
   
   FUNCTION Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2) RETURN CLOB
   IS
      
   
      l_clob_request  CLOB;
      l_clob_response CLOB;
      endPoint_       VARCHAR2(2000);
      error_status_  VARCHAR2(32000);
   BEGIN
   
      endPoint_ := '/rest/consumer_maxprint/V1/getAvailableOrders';
      l_clob_request:= '';
      Execute_Json(token_, host_name_, endPoint_, 'GET', l_clob_request, l_clob_response, error_status_);
   
      IF error_status_ = 'FALSE' THEN
         RETURN l_clob_response;      
      ELSE
         Gravar_Log_Trigger(USER,  'ERROR get_cliente_existe_magento: '||substr(l_clob_response,1,1600));
         RETURN 'ERRO';
      END IF;   
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_ordem_magento');
   RETURN Cust(token_, host_name_);
END get_ordem_magento;


FUNCTION get_clob_alterado (texto_Clob IN CLOB, texto_antigo_ IN VARCHAR2, texto_novo_ IN VARCHAR2 ) RETURN CLOB
IS
   
   FUNCTION Cust (texto_Clob IN CLOB, texto_antigo_ IN VARCHAR2, texto_novo_ IN VARCHAR2 ) RETURN CLOB
   IS  
      l_buffer VARCHAR2 (2000);
      l_buffer_temp VARCHAR2 (4000);
      l_amount BINARY_INTEGER := 2000;
      l_pos INTEGER := 1;
      l_clob_len INTEGER;
      newClob clob := EMPTY_CLOB;
   
   BEGIN
   
      dbms_lob.CreateTemporary(newClob, TRUE );
      l_clob_len := DBMS_LOB.getlength (texto_Clob);
      WHILE l_pos < l_clob_len
      LOOP
         DBMS_LOB.READ (texto_Clob,l_amount,l_pos,l_buffer);
         IF l_buffer IS NOT NULL THEN
            l_buffer_temp := replace(l_buffer,texto_antigo_,texto_novo_);
            DBMS_LOB.writeAppend(newClob, LENGTH(l_buffer_temp), l_buffer_temp);
         END IF;
         l_pos :=   l_pos + l_amount;
      END LOOP;
   
      RETURN newClob;
   
      EXCEPTION
      WHEN OTHERS THEN
          RAISE;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_clob_alterado');
   RETURN Cust(texto_Clob, texto_antigo_, texto_novo_);
END get_clob_alterado;


PROCEDURE Imprimir_clob_dbms (strClob IN CLOB)
IS
   
   PROCEDURE Cust (strClob IN CLOB)
   IS
   
   
      l_buffer VARCHAR2 (2000);
      l_buffer_temp VARCHAR2 (4000);
      l_amount BINARY_INTEGER := 2000;
      l_pos INTEGER := 1;
      l_clob_len INTEGER;
      newClob clob := EMPTY_CLOB;
   
      BEGIN
         dbms_output.put_line('-------------------------');
         dbms_lob.CreateTemporary(newClob, TRUE );
         l_clob_len := DBMS_LOB.getlength (strClob);
         WHILE l_pos < l_clob_len
         LOOP
            DBMS_LOB.READ (strClob,l_amount,l_pos,l_buffer);
            IF l_buffer IS NOT NULL THEN
              dbms_output.put_line(l_buffer);
            END IF;
            l_pos :=   l_pos + l_amount;
         END LOOP;
   
         EXCEPTION
         WHEN OTHERS THEN
            RAISE;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Imprimir_clob_dbms');
   Cust(strClob);
END Imprimir_clob_dbms;


FUNCTION get_ncm (cod_produto_ IN VARCHAR2, site_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (cod_produto_ IN VARCHAR2, site_ IN VARCHAR2) RETURN VARCHAR2
   IS
   
      ncm_ TAX_PART.nbm_id%TYPE;
   
      CURSOR get_cod_ncm (cod_produto__ in VARCHAR2, site__ IN VARCHAR2) IS SELECT 
                                                                              b.nbm_id
                                                                            FROM TAX_PART b
                                                                            WHERE 
                                                                               COMPANY = 'RIO BRANCO'
                                                                               AND b.fiscal_part_type_db = 2
                                                                               AND b.part_no = cod_produto__
                                                                               AND b.contract = site__
                                                                               FETCH FIRST 1 ROWS ONLY;
   BEGIN
   
         OPEN get_cod_ncm(cod_produto_, site_);
         FETCH get_cod_ncm INTO ncm_;
         CLOSE get_cod_ncm;                     
   
         RETURN ncm_;
        
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_ncm');
   RETURN Cust(cod_produto_, site_);
END get_ncm;


PROCEDURE Pesquisar_desconto_venda (cod_produto_ IN VARCHAR2,
                                    site_ IN VARCHAR, 
                                    perc_desconto_vend OUT NUMBER,
                                    perc_desconto_gerente OUT NUMBER,
                                    perc_desconto_diretor OUT NUMBER
                                     )
IS
   
   PROCEDURE Cust (cod_produto_ IN VARCHAR2,
                                       site_ IN VARCHAR, 
                                       perc_desconto_vend OUT NUMBER,
                                       perc_desconto_gerente OUT NUMBER,
                                       perc_desconto_diretor OUT NUMBER
                                        )
   IS
   
   CURSOR get_desconto (cod_produto__ in VARCHAR2, site__ IN VARCHAR2) IS 
                                                                        SELECT 
                                                                           NVL(a.c_discount_salesman,0) AS perc_desconto_vendedor,
                                                                           NVL(a.c_discount_salesman,0) + NVL(a.c_discount_manager,0) AS perc_desconto_gerente,
                                                                           NVL(a.c_discount_salesman,0) + NVL(a.c_discount_manager,0) + NVL(a.c_discount_director,0) AS desconto_diretor
                                                                        FROM SALES_PART a
                                                                        WHERE a.contract = site__
                                                                        AND a.part_no = cod_produto__;
   BEGIN
   
      OPEN get_desconto(cod_produto_, site_);
      FETCH get_desconto INTO perc_desconto_vend,perc_desconto_gerente, perc_desconto_diretor;
      CLOSE get_desconto;                     
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Pesquisar_desconto_venda');
   Cust(cod_produto_, site_, perc_desconto_vend, perc_desconto_gerente, perc_desconto_diretor);
END Pesquisar_desconto_venda;


FUNCTION get_clob_request_foto (imagem_blob_    IN BLOB,
                                tipo_imagem_    IN VARCHAR2,
                                formato_imagem_ IN VARCHAR2,
                                nome_imagem_    IN VARCHAR2,
                                ordem_foto_     IN NUMBER,
                                desabilitado_   IN VARCHAR2,
                                id_media_mag_   IN NUMBER ) RETURN CLOB
IS
   
   FUNCTION Cust (imagem_blob_    IN BLOB,
                                   tipo_imagem_    IN VARCHAR2,
                                   formato_imagem_ IN VARCHAR2,
                                   nome_imagem_    IN VARCHAR2,
                                   ordem_foto_     IN NUMBER,
                                   desabilitado_   IN VARCHAR2,
                                   id_media_mag_   IN NUMBER ) RETURN CLOB
   IS
   
      l_clob_request CLOB; 
   
   BEGIN
   
      l_clob_request := '{"entry":{';
   
      IF NVL(id_media_mag_,0) <> 0 THEN
         l_clob_request := l_clob_request || '"id": '|| id_media_mag_ ||','; 
      END IF;
   
      l_clob_request := l_clob_request || '"media_type":"image",';
      l_clob_request := l_clob_request || '"label":"Image",';
      l_clob_request := l_clob_request || '"position":' || ordem_foto_ || ',';
      l_clob_request := l_clob_request || '"disabled":' || desabilitado_ ||',';
      l_clob_request := l_clob_request ||  tipo_imagem_;
      l_clob_request := l_clob_request || '"content":{';
      l_clob_request := l_clob_request || '"base64EncodedData":"' || REPLACE(REPLACE(base64encode(imagem_blob_), chr(10), ''), chr(13), '') || '",';
      l_clob_request := l_clob_request || '"type":"image/' || formato_imagem_ || '",';
      l_clob_request := l_clob_request || '"name":"' || nome_imagem_ ||'"}}}';
   
      RETURN  l_clob_request;
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_clob_request_foto');
   RETURN Cust(imagem_blob_, tipo_imagem_, formato_imagem_, nome_imagem_, ordem_foto_, desabilitado_, id_media_mag_);
END get_clob_request_foto;


PROCEDURE Create_Quotation(customer_no_             IN VARCHAR2,
                              wanted_delivery_date_    IN DATE,
                              contract_                IN VARCHAR2, 
                              addr_no_                 IN VARCHAR2, 
                              forward_agent_id_        IN VARCHAR2, 
                              operation_id_            IN VARCHAR2, 
                              pay_term_id_             IN VARCHAR2, 
                              ship_via_code_           IN VARCHAR2, 
                              c_salesman_attendant_    IN VARCHAR2,
                              c_inter_site_operation_  IN VARCHAR2,
                              c_not_highlight_freight_ IN VARCHAR2,
                              delivery_terms_          IN VARCHAR2,
                              num_oc_cliente_          IN VARCHAR2,           
                              quotation_no_            IN OUT NOCOPY VARCHAR2)
IS
   
   PROCEDURE Cust(customer_no_             IN VARCHAR2,
                                 wanted_delivery_date_    IN DATE,
                                 contract_                IN VARCHAR2, 
                                 addr_no_                 IN VARCHAR2, 
                                 forward_agent_id_        IN VARCHAR2, 
                                 operation_id_            IN VARCHAR2, 
                                 pay_term_id_             IN VARCHAR2, 
                                 ship_via_code_           IN VARCHAR2, 
                                 c_salesman_attendant_    IN VARCHAR2,
                                 c_inter_site_operation_  IN VARCHAR2,
                                 c_not_highlight_freight_ IN VARCHAR2,
                                 delivery_terms_          IN VARCHAR2,
                                 num_oc_cliente_          IN VARCHAR2,           
                                 quotation_no_            IN OUT NOCOPY VARCHAR2)
   IS
     
      attr_                         VARCHAR2(4000);
      objid_                        VARCHAR2(2000);
      objversion_                   VARCHAR2(2000);
      info_                         VARCHAR2(2000);
      company_                      ORDER_QUOTATION.company%TYPE;
      supply_country_               ORDER_QUOTATION.supply_country%TYPE;   
      calc_disc_flag_               ORDER_QUOTATION.calc_disc_flag%TYPE;   
      currency_code_                ORDER_QUOTATION.currency_code%TYPE;   
      cust_ref_                     ORDER_QUOTATION.cust_ref%TYPE;
      bill_addr_no_                 ORDER_QUOTATION.bill_addr_no%TYPE;
      language_code_                ORDER_QUOTATION.language_code%TYPE;
      delivery_leadtime_            ORDER_QUOTATION.delivery_leadtime%TYPE;
      del_terms_location_           ORDER_QUOTATION.del_terms_location%TYPE;
      ext_transport_calendar_id_    ORDER_QUOTATION.ext_transport_calendar_id%TYPE;
      district_code_                ORDER_QUOTATION.district_code%TYPE;
      market_code_                  ORDER_QUOTATION.agreement_id%TYPE;
      agreement_id_                 ORDER_QUOTATION.agreement_id%TYPE;
      tax_liability_                ORDER_QUOTATION.tax_liability%TYPE;
      jinsui_invoice_db_            ORDER_QUOTATION.jinsui_invoice_db%TYPE;
      vat_db_                       ORDER_QUOTATION.vat_db%TYPE;
      authorize_code_               ORDER_QUOTATION.authorize_code%TYPE;
      additional_discount_          ORDER_QUOTATION.additional_discount%TYPE;
      printed_db_                   ORDER_QUOTATION.printed_db%TYPE;
      quotation_probability_        ORDER_QUOTATION.quotation_probability%TYPE;
      apply_fix_deliv_freight_db_   ORDER_QUOTATION.apply_fix_deliv_freight_db%TYPE;
      ship_addr_in_city_            ORDER_QUOTATION.ship_addr_in_city%TYPE;
      single_occ_addr_flag_         ORDER_QUOTATION.single_occ_addr_flag%TYPE;
      c_water_mark_db_              ORDER_QUOTATION.c_water_mark_db%TYPE;
      picking_leadtime_             ORDER_QUOTATION.picking_leadtime%TYPE;
      freight_map_id_               ORDER_QUOTATION.freight_map_id%TYPE;
      zone_id_                      ORDER_QUOTATION.zone_id%TYPE;
      freight_price_list_no_        ORDER_QUOTATION.freight_price_list_no%TYPE;  
      use_price_incl_tax_db_        ORDER_QUOTATION.use_price_incl_tax_db%TYPE;
      vat_free_vat_code_            ORDER_QUOTATION.vat_free_vat_code%TYPE;
   
      -- p0 -> i_hWndFrame.frmOrderQuotation.sDeliveryTerm
      p0_ VARCHAR2(32000) := '';
   
      -- p1 -> i_hWndFrame.frmOrderQuotation.sDelTermsLocation
      p1_ VARCHAR2(32000) := '';
   
      -- p2 -> i_hWndFrame.frmOrderQuotation.sForwardAgentId
      p2_ VARCHAR2(32000) := '';
   
      -- p3 -> i_hWndFrame.frmOrderQuotation.nLeadTime
      p3_ FLOAT := 0;
   
      -- p4 -> i_hWndFrame.frmOrderQuotation.sExtTransportCalendarId
      p4_ VARCHAR2(32000) := NULL;
   
      -- p5 -> i_hWndFrame.frmOrderQuotation.sFreightMapId
      p5_ VARCHAR2(32000) := NULL;
   
      -- p6 -> i_hWndFrame.frmOrderQuotation.sZoneId
      p6_ VARCHAR2(32000) := NULL;
   
      -- p7 -> i_hWndFrame.frmOrderQuotation.sFreightPriceListNo
      p7_ VARCHAR2(32000) := NULL;
   
      -- p8 -> i_hWndFrame.frmOrderQuotation.nPickingLeadtime
      p8_ FLOAT := 0;
   
      -- p9 -> i_hWndFrame.frmOrderQuotation.ecmbsQuotationNo.i_sMyValue
      p9_ VARCHAR2(32000) := '';
   
      -- p10 -> i_hWndFrame.frmOrderQuotation.dfsContract
      p10_ VARCHAR2(32000) := '';
   
      -- p11 -> i_hWndFrame.frmOrderQuotation.dfsCustomerNo
      p11_ VARCHAR2(32000) := '';
   
      -- p12 -> i_hWndFrame.frmOrderQuotation.dfsShipAddrNo
      p12_ VARCHAR2(32000) := '';
   
      -- p13 -> i_hWndFrame.frmOrderQuotation.dfsShipViaCode
      p13_ VARCHAR2(32000) := '';
   
      -- p14 -> i_hWndFrame.frmOrderQuotation.dfsVendorNo
      p14_ VARCHAR2(32000) := '';
   
      -- p15 -> i_hWndFrame.frmOrderQuotation.dfsSingleOccShipAddrZipCode
      p15_ VARCHAR2(32000) := '';
   
      -- p16 -> i_hWndFrame.frmOrderQuotation.dfsSingleOccShipAddrCity
      p16_ VARCHAR2(32000) := '';
   
      -- p17 -> i_hWndFrame.frmOrderQuotation.dfsSingleOccShipAddrCounty
      p17_ VARCHAR2(32000) := '';
   
      -- p18 -> i_hWndFrame.frmOrderQuotation.dfsSingleOccShipAddrState
      p18_ VARCHAR2(32000) := '';
   
      -- p19 -> i_hWndFrame.frmOrderQuotation.dfsSingleOccShipAddrCountryCode
      p19_ VARCHAR2(32000) := '';
      p20_ VARCHAR2(32000) := '';
      p21_ VARCHAR2(32000) := '';
   
   
   BEGIN
   
      authorize_code_ := '12221';
   
      client_sys.Clear_attr(attr_);
      ORDER_QUOTATION_API.NEW__( info_ , objid_ , objversion_ , attr_ , 'PREPARE' );
      additional_discount_          := Client_SYS.Get_Item_Value('ADDITIONAL_DISCOUNT', attr_);
      printed_db_                   := Client_SYS.Get_Item_Value('PRINTED_DB', attr_);
      quotation_probability_        := Client_SYS.Get_Item_Value('QUOTATION_PROBABILITY', attr_);
      apply_fix_deliv_freight_db_   := Client_SYS.Get_Item_Value('APPLY_FIX_DELIV_FREIGHT_DB', attr_);
      ship_addr_in_city_            := Client_SYS.Get_Item_Value('SHIP_ADDR_IN_CITY', attr_);
      single_occ_addr_flag_         := Client_SYS.Get_Item_Value('SINGLE_OCC_ADDR_FLAG', attr_);
      c_water_mark_db_              := Client_SYS.Get_Item_Value('C_WATER_MARK_DB', attr_);
      company_                      := site_api.get_company(contract_);
      supply_country_                := customer_info_api.get_country(customer_no_);
   
      client_sys.Clear_attr(attr_);
      Client_SYS.Add_To_Attr('CONTRACT', contract_, attr_);
      Client_SYS.Add_To_Attr('COMPANY', company_, attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_NO', customer_no_, attr_);
      Client_SYS.Add_To_Attr('SUPPLY_COUNTRY', supply_country_, attr_);
      Client_SYS.Add_To_Attr('VENDOR_NO', '', attr_);
      Order_Quotation_API.Get_Customer_Defaults__(attr_);
   
      calc_disc_flag_               := Client_SYS.Get_Item_Value('CALC_DISC_FLAG', attr_);
      currency_code_                := Client_SYS.Get_Item_Value('CURRENCY_CODE', attr_);
      cust_ref_                     := Client_SYS.Get_Item_Value('CUST_REF', attr_);
      bill_addr_no_                 := Client_SYS.Get_Item_Value('BILL_ADDR_NO', attr_);
      language_code_                := Client_SYS.Get_Item_Value('LANGUAGE_CODE', attr_);
      delivery_leadtime_            := Client_SYS.Get_Item_Value('DELIVERY_LEADTIME', attr_);
   
      del_terms_location_           := Client_SYS.Get_Item_Value('DEL_TERMS_LOCATION', attr_);
      ext_transport_calendar_id_    := Client_SYS.Get_Item_Value('EXT_TRANSPORT_CALENDAR_ID', attr_);
      district_code_                := Client_SYS.Get_Item_Value('DISTRICT_CODE', attr_);
      market_code_                  := Client_SYS.Get_Item_Value('MARKET_CODE', attr_);
      agreement_id_                 := Client_SYS.Get_Item_Value('AGREEMENT_ID', attr_);
      tax_liability_                := Client_SYS.Get_Item_Value('TAX_LIABILITY', attr_);
      jinsui_invoice_db_            := Client_SYS.Get_Item_Value('JINSUI_INVOICE_DB', attr_);
      vat_db_                       := Client_SYS.Get_Item_Value('VAT_DB', attr_);
   
      -- addrrec_                      := Cust_Ord_Customer_Address_API.Get(customer_no_ , addr_no_ );
      -- shipaddr_                     := Customer_Info_Address_API.Get(customer_no_ , addr_no_ );
      picking_leadtime_             := '0';
      delivery_leadtime_            := '0';
      ext_transport_calendar_id_    := '*';
      -- p10 -> i_hWndFrame.frmOrderQuotation.dfsContract
      p10_ := contract_;
      -- p11 -> i_hWndFrame.frmOrderQuotation.dfsCustomerNo
      p11_ := customer_no_;
      -- p12 -> i_hWndFrame.frmOrderQuotation.dfsShipAddrNo
      p12_ := addr_no_;
      p13_ := ship_via_code_;
   
      IFSRIB.Order_Quotation_API.Fetch_Delivery_Attributes(p2_ , p3_ , p4_ , p5_ , p6_ , p7_ , p8_ , p20_, p21_, p9_ , p10_ , p11_ , p12_ , p13_ , p14_ , 'FALSE', p15_ , p16_ , p17_ , p18_ , p19_ );
   
      freight_map_id_        := p5_;
      freight_price_list_no_ := p7_;
      zone_id_               := p6_;
      use_price_incl_tax_db_ := Customer_Tax_Free_Tax_Code_API.Get_Vat_Free_Vat_Code(customer_no_, addr_no_, company_, supply_country_, '*');
      vat_free_vat_code_ := Customer_Tax_Free_Tax_Code_API.Get_Vat_Free_Vat_Code(customer_no_, addr_no_, company_, supply_country_, '*');
   
      client_sys.Clear_attr(attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_QUO_NO', num_oc_cliente_ , attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_NO', customer_no_, attr_);
      Client_SYS.Add_To_Attr('WANTED_DELIVERY_DATE', wanted_delivery_date_, attr_);
      Client_SYS.Add_To_Attr('REVISION_NO', '1', attr_);
      Client_SYS.Add_To_Attr('AUTHORIZE_CODE', authorize_code_, attr_);
      Client_SYS.Add_To_Attr('CONTRACT', contract_, attr_);
      Client_SYS.Add_To_Attr('CURRENCY_CODE', currency_code_, attr_);
      Client_SYS.Add_To_Attr('OPERATION_ID', operation_id_, attr_);
      Client_SYS.Add_To_Attr('CUST_REF', cust_ref_, attr_);
      Client_SYS.Add_To_Attr('ADDITIONAL_DISCOUNT', additional_discount_, attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_NO', addr_no_, attr_);
      Client_SYS.Add_To_Attr('BILL_ADDR_NO', bill_addr_no_, attr_);
      Client_SYS.Add_To_Attr('PRINTED_DB', printed_db_, attr_);
      Client_SYS.Add_To_Attr('LANGUAGE_CODE', language_code_, attr_);
      Client_SYS.Add_To_Attr('QUOTATION_PROBABILITY', quotation_probability_, attr_);
      Client_SYS.Add_To_Attr('DELIVERY_LEADTIME', delivery_leadtime_, attr_);
      Client_SYS.Add_To_Attr('PICKING_LEADTIME', picking_leadtime_, attr_);
      Client_SYS.Add_To_Attr('SHIP_VIA_CODE', ship_via_code_, attr_);
      Client_SYS.Add_To_Attr('DELIVERY_TERMS', delivery_terms_, attr_);
      Client_SYS.Add_To_Attr('DEL_TERMS_LOCATION', del_terms_location_, attr_);
      Client_SYS.Add_To_Attr('FORWARD_AGENT_ID', forward_agent_id_, attr_);
      Client_SYS.Add_To_Attr('EXT_TRANSPORT_CALENDAR_ID', ext_transport_calendar_id_, attr_);
      Client_SYS.Add_To_Attr('FREIGHT_MAP_ID', freight_map_id_, attr_);
      Client_SYS.Add_To_Attr('ZONE_ID', zone_id_, attr_);
      Client_SYS.Add_To_Attr('FREIGHT_PRICE_LIST_NO', freight_price_list_no_, attr_);
      Client_SYS.Add_To_Attr('APPLY_FIX_DELIV_FREIGHT_DB', apply_fix_deliv_freight_db_, attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_NO_PAY_ADDR_NO', '', attr_);
      Client_SYS.Add_To_Attr('REGION_CODE', '', attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_NO_PAY_ADDR_NO', '', attr_);
      Client_SYS.Add_To_Attr('DISTRICT_CODE', district_code_, attr_);
      Client_SYS.Add_To_Attr('PAY_TERM_ID', pay_term_id_, attr_);
      Client_SYS.Add_To_Attr('AGREEMENT_ID', agreement_id_, attr_);      
      Client_SYS.Add_To_Attr('USE_PRICE_INCL_TAX_DB', use_price_incl_tax_db_, attr_);      
      Client_SYS.Add_To_Attr('SUPPLY_COUNTRY', supply_country_, attr_);
      Client_SYS.Add_To_Attr('TAX_LIABILITY', tax_liability_, attr_);
      Client_SYS.Add_To_Attr('JINSUI_INVOICE_DB', jinsui_invoice_db_, attr_);
      Client_SYS.Add_To_Attr('VAT_DB', vat_db_, attr_);
      Client_SYS.Add_To_Attr('COMPANY', company_, attr_);
      Client_SYS.Add_To_Attr('CALC_DISC_FLAG', calc_disc_flag_, attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_IN_CITY', ship_addr_in_city_, attr_);
      Client_SYS.Add_To_Attr('SINGLE_OCC_ADDR_FLAG', single_occ_addr_flag_, attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_NAME', '', attr_);      
      Client_SYS.Add_To_Attr('VAT_FREE_VAT_CODE', vat_free_vat_code_, attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDRESS1', '', attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDRESS2', '', attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_ZIP_CODE', '', attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_CITY', '', attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_STATE', '', attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_COUNTY', '', attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_COUNTRY_CODE', '', attr_);
      Client_SYS.Add_To_Attr('COUNTRY_CODE', 'BR', attr_);
      Client_SYS.Add_To_Attr('C_SALESMAN_ATTENDANT', c_salesman_attendant_, attr_);
      Client_SYS.Add_To_Attr('C_INTER_SITE_OPERATION', c_inter_site_operation_, attr_);
      Client_SYS.Add_To_Attr('C_WATER_MARK_DB', c_water_mark_db_, attr_);
      Client_SYS.Add_To_Attr('C_PAYMENT_FUTURE', 'FALSE', attr_);
      Client_SYS.Add_To_Attr('C_FORWARDER_EXCLUSIVE', 'FALSE', attr_);
      Client_SYS.Add_To_Attr('C_NOT_HIGHLIGHT_FREIGHT', c_not_highlight_freight_,  attr_);
      Client_SYS.Add_To_Attr('QUOTATION_NO', quotation_no_, attr_);      
   
      p0_ := NULL;
      p1_ := NULL;
      p2_ := NULL;
      ORDER_QUOTATION_API.NEW__( p0_ , p1_ , p2_ , attr_ , 'DO' );
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Create_Quotation');
   Cust(customer_no_, wanted_delivery_date_, contract_, addr_no_, forward_agent_id_, operation_id_, pay_term_id_, ship_via_code_, c_salesman_attendant_, c_inter_site_operation_, c_not_highlight_freight_, delivery_terms_, num_oc_cliente_, quotation_no_);
END Create_Quotation;


PROCEDURE Create_Quotation_Item( quotation_no_           IN VARCHAR2,
                                    catalog_no_             IN VARCHAR2, 
                                    contract_               IN VARCHAR2, 
                                    price_list_no_          IN VARCHAR2,
                                    vendor_no_              IN VARCHAR2,
                                    wanted_delivery_date_   IN VARCHAR2, 
                                    c_inter_site_operation_ IN VARCHAR2,
                                    forward_agent_id_       IN VARCHAR2,
                                    ipi_perc_               in NUMBER,
                                    sale_unit_price_calc_   IN NUMBER, 
                                    discount_perc_calc_     IN NUMBER,   
                                    buy_qty_due_            IN NUMBER 
                                    )
IS
   
   PROCEDURE Cust( quotation_no_           IN VARCHAR2,
                                       catalog_no_             IN VARCHAR2, 
                                       contract_               IN VARCHAR2, 
                                       price_list_no_          IN VARCHAR2,
                                       vendor_no_              IN VARCHAR2,
                                       wanted_delivery_date_   IN VARCHAR2, 
                                       c_inter_site_operation_ IN VARCHAR2,
                                       forward_agent_id_       IN VARCHAR2,
                                       ipi_perc_               in NUMBER,
                                       sale_unit_price_calc_   IN NUMBER, 
                                       discount_perc_calc_     IN NUMBER,   
                                       buy_qty_due_            IN NUMBER 
                                       )
   IS
      
      company_                      ORDER_QUOTATION_LINE.company%TYPE;
      delivery_type_                ORDER_QUOTATION_LINE.delivery_type%TYPE;
      catalog_no_temp_              ORDER_QUOTATION_LINE.catalog_no%TYPE;
      catalog_desc_                 ORDER_QUOTATION_LINE.catalog_desc%TYPE;
      customer_part_no_             ORDER_QUOTATION_LINE.customer_part_no%TYPE;
      customer_part_unit_meas_      ORDER_QUOTATION_LINE.customer_part_unit_meas%TYPE;
      configuration_id_             ORDER_QUOTATION_LINE.configuration_id%TYPE;
      condition_code_               ORDER_QUOTATION_LINE.condition_code%TYPE;
      cost_                         ORDER_QUOTATION_LINE.cost%TYPE;
      sales_unit_measure_           ORDER_QUOTATION_LINE.sales_unit_measure%TYPE;
      part_price_                   ORDER_QUOTATION_LINE.part_price%TYPE;
      price_source_                 ORDER_QUOTATION_LINE.price_source%TYPE;
      price_source_id_              ORDER_QUOTATION_LINE.price_source_id%TYPE;
      sale_unit_price_              ORDER_QUOTATION_LINE.sale_unit_price%TYPE;
      base_unit_price_incl_tax_     ORDER_QUOTATION_LINE.base_unit_price_incl_tax%TYPE;
      discount_                     ORDER_QUOTATION_LINE.discount%TYPE;
      order_supply_type_            ORDER_QUOTATION_LINE.order_supply_type%TYPE;
      charged_item_db_              ORDER_QUOTATION_LINE.charged_item_db%TYPE;
      vat_db_                       ORDER_QUOTATION_LINE.vat_db%TYPE;
      tax_liability_                ORDER_QUOTATION_LINE.tax_liability%TYPE;
      default_addr_flag_db_         ORDER_QUOTATION_LINE.default_addr_flag_db%TYPE;
      single_occ_addr_flag_         ORDER_QUOTATION_LINE.single_occ_addr_flag%TYPE;
      end_customer_id_              ORDER_QUOTATION_LINE.end_customer_id%TYPE;
      ship_addr_no_                 ORDER_QUOTATION_LINE.ship_addr_no%TYPE;
      delivery_terms_               ORDER_QUOTATION_LINE.delivery_terms%TYPE;
      del_terms_location_           ORDER_QUOTATION_LINE.del_terms_location%TYPE;
      probability_to_win_           ORDER_QUOTATION_LINE.probability_to_win%TYPE;
      release_planning_db_          ORDER_QUOTATION_LINE.release_planning_db%TYPE;
      ctp_planned_db_               ORDER_QUOTATION_LINE.ctp_planned_db%TYPE;
      self_billing_db_              ORDER_QUOTATION_LINE.self_billing_db%TYPE;
      customer_part_conv_factor_    ORDER_QUOTATION_LINE.customer_part_conv_factor%TYPE;
      catalog_type_                 ORDER_QUOTATION_LINE.catalog_type%TYPE;
      catalog_type_db_              ORDER_QUOTATION_LINE.catalog_type_db%TYPE;
      currency_rate_                ORDER_QUOTATION_LINE.currency_rate%TYPE;
      price_conv_factor_            ORDER_QUOTATION_LINE.price_conv_factor%TYPE;
      conv_factor_                  ORDER_QUOTATION_LINE.conv_factor%TYPE;
      inverted_conv_factor_         ORDER_QUOTATION_LINE.inverted_conv_factor%TYPE;
      revised_qty_due_              ORDER_QUOTATION_LINE.revised_qty_due%TYPE;
      price_source_net_price_db_    ORDER_QUOTATION_LINE.price_source_net_price_db%TYPE;
      part_level_db_                ORDER_QUOTATION_LINE.part_level_db%TYPE;
      part_level_id_                ORDER_QUOTATION_LINE.part_level_id%TYPE;
      customer_level_db_            ORDER_QUOTATION_LINE.customer_level_db%TYPE;
      customer_level_id_            ORDER_QUOTATION_LINE.customer_level_id%TYPE;
      cust_part_invert_conv_fact_   ORDER_QUOTATION_LINE.cust_part_invert_conv_fact%TYPE;
      rental_db_                    ORDER_QUOTATION_LINE.rental_db%TYPE;
      base_sale_unit_price_         ORDER_QUOTATION_LINE.base_sale_unit_price%TYPE;
      unit_price_incl_tax_          ORDER_QUOTATION_LINE.unit_price_incl_tax%TYPE;
      classification_part_no_       ORDER_QUOTATION_LINE.classification_part_no%TYPE;
      classification_unit_meas_     ORDER_QUOTATION_LINE.classification_unit_meas%TYPE;
      fee_code_                     ORDER_QUOTATION_LINE.fee_code%TYPE;
      tax_class_id_                 ORDER_QUOTATION_LINE.tax_class_id%TYPE;
      c_cubic_weight_               ORDER_QUOTATION_LINE.c_cubic_weight%TYPE;
      vendor_no_temp_               ORDER_QUOTATION_LINE.vendor_no%TYPE;
      p0_                           VARCHAR2(32000);
      p1_                           VARCHAR2(32000);
      p2_                           VARCHAR2(32000);
      attr_                         VARCHAR2(4000);
      objid_                        VARCHAR2(32000);
      objversion_                   VARCHAR2(32000);
      info_                         VARCHAR2(32000);
                 
   
   BEGIN
   
      Language_SYS.Set_Language('bp');
   
      company_ := site_api.get_company(contract_);
      catalog_no_temp_ := catalog_no_;    
      objid_           := NULL;
      objversion_      := NULL;
      delivery_type_   := NULL; 
      discount_        := discount_perc_calc_;
      c_cubic_weight_  := 0;
   
      IF Mpccom_Ship_Via_API.Get_Mode_Of_Transport_Db(Order_Quotation_API.Get_Ship_Via_Code(quotation_no_)) = 3 
                                       OR NVL(Order_Quotation_API.Get_Ship_Via_Code(quotation_no_), 'TS') = 'TS' THEN --Road Transport
         IF NVL(Part_Catalog_API.Get_Cubic_Weight_Land(catalog_no_),0) > 0 THEN
            c_cubic_weight_ := buy_qty_due_ * Part_Catalog_API.Get_Cubic_Weight_Land(catalog_no_);
         ELSE
            c_cubic_weight_ := 0;
         END IF;
      ELSIF Mpccom_Ship_Via_API.Get_Mode_Of_Transport_Db(Order_Quotation_API.Get_Ship_Via_Code(quotation_no_)) = 4 THEN --Air Transport
         IF NVL(Part_Catalog_API.Get_Cubic_Weight_Air(catalog_no_),0) > 0 THEN
            c_cubic_weight_ := buy_qty_due_ * Part_Catalog_API.Get_Cubic_Weight_Air(catalog_no_);
         ELSE
            c_cubic_weight_ := 0;
         END IF;   
      END IF;
   
      client_sys.Clear_attr(attr_);
      Client_SYS.Add_To_Attr('LINE_ITEM_NO', '0', attr_);
      Client_SYS.Add_To_Attr('QUOTATION_NO', quotation_no_, attr_);
      Client_SYS.Add_To_Attr('RENTAL_DB', 'FALSE', attr_);
      ORDER_QUOTATION_LINE_API.NEW__( info_ , objid_ , objversion_ , attr_ , 'PREPARE' );
      vat_db_                    := Client_SYS.Get_Item_Value('VAT_DB', attr_);
      tax_liability_             := Client_SYS.Get_Item_Value('TAX_LIABILITY', attr_);
      default_addr_flag_db_      := Client_SYS.Get_Item_Value('DEFAULT_ADDR_FLAG_DB', attr_);
      single_occ_addr_flag_      := Client_SYS.Get_Item_Value('SINGLE_OCC_ADDR_FLAG', attr_);
      end_customer_id_           := Client_SYS.Get_Item_Value('END_CUSTOMER_ID', attr_);
      ship_addr_no_              := Client_SYS.Get_Item_Value('SHIP_ADDR_NO', attr_);
      del_terms_location_        := Client_SYS.Get_Item_Value('DEL_TERMS_LOCATION', attr_);
      probability_to_win_        := Client_SYS.Get_Item_Value('PROBABILITY_TO_WIN', attr_);
      release_planning_db_       := Client_SYS.Get_Item_Value('RELEASE_PLANNING_DB', attr_);
      ctp_planned_db_            := Client_SYS.Get_Item_Value('CTP_PLANNED_DB', attr_);
   
      client_sys.Clear_attr(attr_);
      Client_SYS.Add_To_Attr('BUY_QTY_DUE', buy_qty_due_, attr_);
      Client_SYS.Add_To_Attr('RENTAL_DB', 'FALSE', attr_);
      Order_Quotation_Line_API.Get_Line_Defaults__(info_ , attr_ , catalog_no_temp_ , quotation_no_ );
      configuration_id_          := Client_SYS.Get_Item_Value('CONFIGURATION_ID', attr_);
      conv_factor_               := Client_SYS.Get_Item_Value('CONV_FACTOR', attr_);
      revised_qty_due_           := Client_SYS.Get_Item_Value('REVISED_QTY_DUE', attr_);
      cost_                      := Client_SYS.Get_Item_Value('COST', attr_);
      price_conv_factor_         := Client_SYS.Get_Item_Value('PRICE_CONV_FACTOR', attr_);
      sales_unit_measure_        := Client_SYS.Get_Item_Value('SALES_UNIT_MEASURE', attr_);
      catalog_type_              := Client_SYS.Get_Item_Value('CATALOG_TYPE', attr_);
      catalog_type_db_           := Client_SYS.Get_Item_Value('CATALOG_TYPE_DB', attr_);
   
      client_sys.Clear_attr(attr_);
      Order_Quotation_Line_API.Get_Quote_Line_Price(attr_ , quotation_no_ , '' , '' , 0 , catalog_no_ , buy_qty_due_ , price_list_no_ , NULL , '' , '' , '' , NULL );
      catalog_desc_              := Client_SYS.Get_Item_Value('CATALOG_DESC', attr_);
      currency_rate_             := Client_SYS.Get_Item_Value('CURRENCY_RATE', attr_);
      sale_unit_price_           := Client_SYS.Get_Item_Value('SALE_UNIT_PRICE', attr_);
      part_price_                := Client_SYS.Get_Item_Value('SALE_UNIT_PRICE', attr_);
      unit_price_incl_tax_       := Client_SYS.Get_Item_Value('UNIT_PRICE_INCL_TAX', attr_);
      base_sale_unit_price_      := Client_SYS.Get_Item_Value('BASE_SALE_UNIT_PRICE', attr_);
      base_unit_price_incl_tax_  := Client_SYS.Get_Item_Value('BASE_UNIT_PRICE_INCL_TAX', attr_);
      price_source_              := Client_SYS.Get_Item_Value('PRICE_SOURCE', attr_);
      charged_item_db_           := Client_SYS.Get_Item_Value('CHARGED_ITEM_DB', attr_);
      price_source_id_           := Client_SYS.Get_Item_Value('PRICE_SOURCE_ID', attr_);
      price_source_net_price_db_ := Client_SYS.Get_Item_Value('PRICE_SOURCE_NET_PRICE_DB', attr_);
      customer_part_no_          := Client_SYS.Get_Item_Value('CUSTOMER_PART_NO', attr_);
      customer_part_conv_factor_ := Client_SYS.Get_Item_Value('CUSTOMER_PART_CONV_FACTOR', attr_);
      customer_part_unit_meas_   := Client_SYS.Get_Item_Value('CUSTOMER_PART_UNIT_MEAS', attr_);
      condition_code_            := Client_SYS.Get_Item_Value('CONDITION_CODE', attr_);
      self_billing_db_           := Client_SYS.Get_Item_Value('SELF_BILLING_DB', attr_);
      part_level_db_             := Client_SYS.Get_Item_Value('PART_LEVEL_DB', attr_);
      part_level_id_             := Client_SYS.Get_Item_Value('PART_LEVEL_ID', attr_);
      customer_level_db_         := Client_SYS.Get_Item_Value('CUSTOMER_LEVEL_DB', attr_);
      customer_level_id_         := Client_SYS.Get_Item_Value('CUSTOMER_LEVEL_ID', attr_);
      inverted_conv_factor_      := Client_SYS.Get_Item_Value('INVERTED_CONV_FACTOR', attr_);
      cust_part_invert_conv_fact_ := Client_SYS.Get_Item_Value('CUST_PART_INVERT_CONV_FACT', attr_);
      fee_code_                  := Client_SYS.Get_Item_Value('FEE_CODE', attr_);
      tax_class_id_              := Client_SYS.Get_Item_Value('TAX_CLASS_ID', attr_);
      rental_db_                 := 'FALSE';
   
   
      -- valor do campo sera IO
      order_supply_type_    := Order_Supply_Type_Api.Get_Client_Value(0);     
      vendor_no_temp_       := NULL;
      IF c_inter_site_operation_ = 'TRUE' THEN
         -- valor do campo sera IPT
         vendor_no_temp_       := vendor_no_;
         order_supply_type_    := Order_Supply_Type_Api.Get_Client_Value(11);
      END IF;
   
      sale_unit_price_           := ROUND(sale_unit_price_calc_ / (1 + (ipi_perc_/100)), 2);
      base_sale_unit_price_      := sale_unit_price_;
      unit_price_incl_tax_       := sale_unit_price_;
      base_unit_price_incl_tax_  := sale_unit_price_;
   
      client_sys.Clear_attr(attr_);
      Client_SYS.Add_To_Attr('ORDER_SUPPLY_TYPE', order_supply_type_, attr_);
      Client_SYS.Add_To_Attr('VENDOR_NO', vendor_no_temp_, attr_);
      Client_SYS.Add_To_Attr('CHARGED_ITEM_DB', charged_item_db_, attr_);
      Client_SYS.Add_To_Attr('BASE_SALE_UNIT_PRICE', base_sale_unit_price_, attr_);
      Client_SYS.Add_To_Attr('SALE_UNIT_PRICE', sale_unit_price_, attr_);
      Client_SYS.Add_To_Attr('BASE_UNIT_PRICE_INCL_TAX', base_unit_price_incl_tax_, attr_);
      Client_SYS.Add_To_Attr('UNIT_PRICE_INCL_TAX', unit_price_incl_tax_, attr_);
      Client_SYS.Add_To_Attr('PART_PRICE', part_price_, attr_);
   
      Client_SYS.Add_To_Attr('CUSTOMER_PART_NO', customer_part_no_, attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_PART_BUY_QTY', '', attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_PART_UNIT_MEAS', customer_part_unit_meas_, attr_);
      Client_SYS.Add_To_Attr('CATALOG_NO', catalog_no_, attr_);
      Client_SYS.Add_To_Attr('CATALOG_DESC', catalog_desc_, attr_);
      Client_SYS.Add_To_Attr('BUY_QTY_DUE', buy_qty_due_, attr_);
      Client_SYS.Add_To_Attr('DESIRED_QTY', buy_qty_due_, attr_);
      Client_SYS.Add_To_Attr('CONFIGURATION_ID', configuration_id_, attr_);
      Client_SYS.Add_To_Attr('CONDITION_CODE', condition_code_, attr_);
      Client_SYS.Add_To_Attr('COST', cost_, attr_);
      Client_SYS.Add_To_Attr('PRICE_LIST_NO', price_list_no_, attr_);
      Client_SYS.Add_To_Attr('SALES_UNIT_MEASURE', sales_unit_measure_, attr_);
   
      Client_SYS.Add_To_Attr('PRICE_SOURCE', price_source_, attr_);
      Client_SYS.Add_To_Attr('PRICE_SOURCE_ID', price_source_id_, attr_);
   
      Client_SYS.Add_To_Attr('DISCOUNT', 0, attr_);
      Client_SYS.Add_To_Attr('C_RB_DISCOUNT', discount_, attr_);
      Client_SYS.Add_To_Attr('DELIVERY_TYPE', delivery_type_, attr_);
      Client_SYS.Add_To_Attr('VAT_DB', vat_db_, attr_);
      Client_SYS.Add_To_Attr('TAX_LIABILITY', tax_liability_, attr_);
      Client_SYS.Add_To_Attr('FEE_CODE', fee_code_, attr_);
      Client_SYS.Add_To_Attr('DEFAULT_ADDR_FLAG_DB', default_addr_flag_db_, attr_);
      Client_SYS.Add_To_Attr('SINGLE_OCC_ADDR_FLAG', single_occ_addr_flag_, attr_);
      Client_SYS.Add_To_Attr('END_CUSTOMER_ID', end_customer_id_, attr_);
      Client_SYS.Add_To_Attr('SHIP_ADDR_NO', ship_addr_no_, attr_);
      Client_SYS.Add_To_Attr('DELIVERY_TERMS', delivery_terms_, attr_);
      Client_SYS.Add_To_Attr('DEL_TERMS_LOCATION', del_terms_location_, attr_);
      Client_SYS.Add_To_Attr('PROBABILITY_TO_WIN', probability_to_win_, attr_);
      Client_SYS.Add_To_Attr('RELEASE_PLANNING_DB', release_planning_db_, attr_);
      Client_SYS.Add_To_Attr('CTP_PLANNED_DB', ctp_planned_db_, attr_);
      Client_SYS.Add_To_Attr('SELF_BILLING_DB', self_billing_db_, attr_);
      Client_SYS.Add_To_Attr('LINE_ITEM_NO', '0', attr_);
      Client_SYS.Add_To_Attr('QUOTATION_NO', quotation_no_, attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_PART_CONV_FACTOR', customer_part_conv_factor_, attr_);
      Client_SYS.Add_To_Attr('CATALOG_TYPE', catalog_type_, attr_);
      Client_SYS.Add_To_Attr('CATALOG_TYPE_DB', catalog_type_db_, attr_);
      Client_SYS.Add_To_Attr('CONTRACT', contract_, attr_);
      Client_SYS.Add_To_Attr('PART_NO', catalog_no_, attr_);
      Client_SYS.Add_To_Attr('CURRENCY_RATE', currency_rate_, attr_);
      Client_SYS.Add_To_Attr('PRICE_CONV_FACTOR', price_conv_factor_, attr_);
      Client_SYS.Add_To_Attr('CONV_FACTOR', conv_factor_, attr_);
      Client_SYS.Add_To_Attr('INVERTED_CONV_FACTOR', inverted_conv_factor_, attr_);
      Client_SYS.Add_To_Attr('REVISED_QTY_DUE', revised_qty_due_, attr_);
      Client_SYS.Add_To_Attr('COMPANY', company_, attr_);
      Client_SYS.Add_To_Attr('PRICE_SOURCE_NET_PRICE_DB', price_source_net_price_db_, attr_);
      Client_SYS.Add_To_Attr('PART_LEVEL_DB', part_level_db_, attr_);
      Client_SYS.Add_To_Attr('PART_LEVEL_ID', part_level_id_, attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_LEVEL_DB', customer_level_db_, attr_);
      Client_SYS.Add_To_Attr('CUSTOMER_LEVEL_ID', customer_level_id_, attr_);
      Client_SYS.Add_To_Attr('CUST_PART_INVERT_CONV_FACT', cust_part_invert_conv_fact_, attr_);
      Client_SYS.Add_To_Attr('RENTAL_DB', rental_db_, attr_);
      Client_SYS.Add_To_Attr('TAX_CLASS_ID', tax_class_id_, attr_);
      Client_SYS.Add_To_Attr('WANTED_DELIVERY_DATE', wanted_delivery_date_, attr_);
      Client_SYS.Add_To_Attr('C_CUBIC_WEIGHT', c_cubic_weight_, attr_);
   
      info_ := NULL;
      objid_ := NULL;
      objversion_ := NULL;
      ORDER_QUOTATION_LINE_API.NEW__( info_ , objid_ , objversion_ , attr_ , 'DO' );
   
   
      Client_sys.Clear_attr(attr_);
      Client_SYS.Add_To_Attr('BASE_SALE_UNIT_PRICE', base_sale_unit_price_, attr_);
      Client_SYS.Add_To_Attr('SALE_UNIT_PRICE', sale_unit_price_, attr_);
      Client_SYS.Add_To_Attr('BASE_UNIT_PRICE_INCL_TAX', base_unit_price_incl_tax_, attr_);
      Client_SYS.Add_To_Attr('UNIT_PRICE_INCL_TAX', unit_price_incl_tax_, attr_);
      info_ := NULL;
      ORDER_QUOTATION_LINE_API.MODIFY__( info_ , objid_ , objversion_ , attr_ , 'DO' );
   
      p2_ := NULL;
          
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Create_Quotation_Item');
   Cust(quotation_no_, catalog_no_, contract_, price_list_no_, vendor_no_, wanted_delivery_date_, c_inter_site_operation_, forward_agent_id_, ipi_perc_, sale_unit_price_calc_, discount_perc_calc_, buy_qty_due_);
END Create_Quotation_Item;


PROCEDURE Create_Order(quotation_no_            IN VARCHAR2,
                       lose_win_note_           IN VARCHAR2,
                       customer_po_no_          IN VARCHAR2,
                       fiscal_note_obs_         IN VARCHAR2,
                       reason_id_               IN VARCHAR2,
                       cust_ref_                IN VARCHAR2,
                       order_no_                IN OUT NOCOPY VARCHAR2)
IS
   
   PROCEDURE Cust(quotation_no_            IN VARCHAR2,
                          lose_win_note_           IN VARCHAR2,
                          customer_po_no_          IN VARCHAR2,
                          fiscal_note_obs_         IN VARCHAR2,
                          reason_id_               IN VARCHAR2,
                          cust_ref_                IN VARCHAR2,
                          order_no_                IN OUT NOCOPY VARCHAR2)
   IS
      
      attr_                         VARCHAR2(4000);
      objid_                        VARCHAR2(2000);
      objversion_                   VARCHAR2(2000);
      info_                         VARCHAR2(2000);
      note_id_                      VARCHAR2(100);
      objstate_                     VARCHAR2(2000);
      c_inter_site_operation_       VARCHAR2(10);
   
      CURSOR get_data_order_quotation(quotation_no__ IN VARCHAR2) IS
                                                                     SELECT a.rowid objid,
                                                                            TO_CHAR(a.rowversion, 'YYYYMMDDHH24MISS') objversion,
                                                                            a.rowstate objstate,
                                                                            C_INTER_SITE_OPERATION
                                                                     FROM   order_quotation_tab a
                                                                     WHERE  a.quotation_no = quotation_no__;
   
      CURSOR get_data_customer_order (order_no__ IN VARCHAR2)IS
                                                                 SELECT a.note_id,
                                                                        a.rowid objid,
                                                                        TO_CHAR(a.rowversion, 'YYYYMMDDHH24MISS') objversion
                                                                 FROM   customer_order_tab a
                                                                 WHERE  a.order_no = order_no__;
   
      msg_ VARCHAR2(3000);
   BEGIN
   
         Language_SYS.Set_Language('bp');
         OPEN  get_data_order_quotation (quotation_no_);
         FETCH get_data_order_quotation INTO objid_, objversion_, objstate_, c_inter_site_operation_;
         IF get_data_order_quotation%FOUND THEN
   
            client_sys.Clear_attr(attr_);
   
            IF objstate_ = 'Planned' THEN
               ORDER_QUOTATION_API.RELEASE__( info_ , objid_ , objversion_ , attr_ , 'DO' );
            END IF;
   
            client_sys.Clear_attr(attr_);
            Client_SYS.Add_To_Attr('ORDER_NO', quotation_no_, attr_);
            IF NVL(c_inter_site_operation_, 'FALSE') = 'TRUE' THEN
               Client_SYS.Add_To_Attr('ORDER_ID', 'OIS', attr_);
            ELSE
               Client_SYS.Add_To_Attr('ORDER_ID', 'NO', attr_);
            END IF;
            Client_SYS.Add_To_Attr('LOSE_WIN_NOTE', lose_win_note_, attr_);
            Client_SYS.Add_To_Attr('CUSTOMER_PO_NO', customer_po_no_, attr_);
   
            Order_Quotation_API.Create_Order(quotation_no_ , 
                                             info_ , 
                                             attr_ , 
                                             'TRUE' , 
                                             'FALSE' , 
                                             'FALSE' );
   
            order_no_ := Client_SYS.Get_Item_Value('CREATED_ORDER_NO', attr_);
   
            OPEN  get_data_customer_order(order_no_);
            FETCH get_data_customer_order INTO note_id_, objid_, objversion_;
            IF get_data_customer_order%FOUND THEN
               IF lose_win_note_ IS NOT NULL THEN
                  Client_SYS.Clear_attr(attr_);
                  Client_SYS.Add_To_Attr('NOTE_TEXT', lose_win_note_, attr_);
                  CUSTOMER_ORDER_API.MODIFY__( info_ , objid_ , objversion_ , attr_ , 'DO' );
               END IF;
   
               IF fiscal_note_obs_ IS NOT NULL THEN
                  client_sys.Clear_attr(attr_);
                  Client_SYS.Add_To_Attr('NOTE_ID', note_id_, attr_);
                  DOCUMENT_TEXT_API.NEW__( info_ , objid_ , objversion_ , attr_ , 'PREPARE' );
   
                  client_sys.Clear_attr(attr_);
                  Client_SYS.Add_To_Attr('OUTPUT_TYPE', 'NFE', attr_);
                  Client_SYS.Add_To_Attr('NOTE_TEXT', fiscal_note_obs_, attr_);
                  Client_SYS.Add_To_Attr('NOTE_ID', note_id_, attr_);
                  DOCUMENT_TEXT_API.NEW__( info_ , objid_ , objversion_ , attr_ , 'DO' );
               END IF;
            END IF;
            CLOSE get_data_customer_order; 
         END IF;   
       CLOSE get_data_order_quotation;   
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Create_Order');
   Cust(quotation_no_, lose_win_note_, customer_po_no_, fiscal_note_obs_, reason_id_, cust_ref_, order_no_);
END Create_Order;


PROCEDURE Enviar_Email (text_ IN VARCHAR2, label_ IN VARCHAR2)
IS
   
   PROCEDURE Cust (text_ IN VARCHAR2, label_ IN VARCHAR2)
   IS
   
   BEGIN
      command_SYS.Mail('IFSRIB', Object_Property_API.Get_Value('MagentoConfiguration', 'Site', 'EMAILS'), text_ ,NULL, NULL, NULL, label_);
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Enviar_Email');
   Cust(text_, label_);
END Enviar_Email;


PROCEDURE Execute_Dados_Pedido_Consumer (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
IS
   
   PROCEDURE Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
   IS
      l_clob_response             CLOB;
      obj0_                       pljson;
      obj1_                       pljson;
      obj2_                       pljson;
      json_detalhe_ov_            pljson;
      json_item_dados_            pljson;
      json_item_impostos_         pljson;
      obj_json_list_              pljson_list;
      json_ordens_                pljson_list;
      json_ordens_itens_          pljson_list;
      obj_value_json              pljson_value;
      id_quotation_ifs            ORDER_QUOTATION.quotation_no%TYPE;
      type_order_                 CUSTOMER_ORDER.ORDER_ID%TYPE;
      contract_stock_             ORDER_QUOTATION.CONTRACT%TYPE;
      contract_sales_             ORDER_QUOTATION.CONTRACT%TYPE;
      pay_term_id_                ORDER_QUOTATION.PAY_TERM_ID%TYPE;
      forward_agent_id_           ORDER_QUOTATION.FORWARD_AGENT_ID%TYPE ;
      c_not_highlight_freight_    ORDER_QUOTATION.c_not_highlight_freight%TYPE;
      ship_via_code_              ORDER_QUOTATION.ship_via_code%TYPE;
      customer_quo_no_            ORDER_QUOTATION.CUSTOMER_QUO_NO%TYPE;
      customer_no_                ORDER_QUOTATION.customer_no%TYPE;
      ship_addr_no_               ORDER_QUOTATION.ship_addr_no%TYPE;
      bill_addr_no_               ORDER_QUOTATION.bill_addr_no%TYPE;
      operation_id_               ORDER_QUOTATION.OPERATION_ID%TYPE; 
      inter_site_operation_       ORDER_QUOTATION.C_INTER_SITE_OPERATION%TYPE;
      salesman_attendant_         ORDER_QUOTATION.C_SALESMAN_ATTENDANT%TYPE;
      delivery_terms_             ORDER_QUOTATION.DELIVERY_TERMS%TYPE;
      id_end_entrega_             ORDER_QUOTATION.SHIP_ADDR_NO%TYPE;
      id_end_cobranca_            ORDER_QUOTATION.BILL_ADDR_NO%TYPE;
      id_quotation_ifs_           ORDER_QUOTATION.QUOTATION_NO%TYPE;
      price_list_no_              ORDER_QUOTATION_LINE.price_list_no%TYPE; 
      sku_                        ORDER_QUOTATION_LINE.PART_NO%TYPE; 
      part_no_                    ORDER_QUOTATION_LINE.PART_NO%TYPE; 
      key_ext_atrib_              VARCHAR2(3);
      customer_no_temp_           VARCHAR2(40);  
      website_                    VARCHAR2(100);
      increment_id_               VARCHAR2(25);
      quote_id_                   VARCHAR2(25);
      item_id_                    NUMBER; 
      entity_id_                  NUMBER;
      total_shipping_highlighted_ NUMBER;  
      buy_qty_due_                NUMBER; 
      sale_unit_price_            NUMBER; 
      sale_unit_price_original_   NUMBER;
      discount_perc_calc_         NUMBER;
      ipi_percentage_             NUMBER;
      obs_nf_                     VARCHAR2(300);
      obs_pedido_                 VARCHAR2(300);
      num_oc_cliente_             VARCHAR2(50);
      info_                       VARCHAR2(32000);
      objid_                      VARCHAR2(32000);
      objversion_                 VARCHAR2(32000);
      attr_                       VARCHAR2(32000);
      
      
   BEGIN
   
      l_clob_response:= get_ordem_magento (token_, host_name_ );
   
      json_ordens_ := pljson_list(l_clob_response);
      FOR i IN 1 .. json_ordens_.count LOOP
         obj1_ := pljson(json_ordens_.get(i));
         obj_value_json := obj1_.get('store_name');
         website_ := obj_value_json.get_string;
         IF NOT UPPER(website_) LIKE  '%CONSUMER%'  THEN
            CONTINUE;
         END IF;
         --  ---------------cabecalho da ordem de venda---------
   
         obj_value_json := obj1_.get('entity_id');
         entity_id_ := obj_value_json.get_string;    
         -- Verificar se a ordem de vendo do magento ja existe na tabela
         IF get_existe_ov_consumer(entity_id_) = 1 THEN
            CONTINUE; 
         END IF;
   
         obj_value_json := obj1_.get('quote_id');
         quote_id_ := obj_value_json.get_string; 
   
         obj_value_json := obj1_.get('customer_email');
         customer_no_temp_ := obj_value_json.get_string;    
         customer_no_      := SUBSTR(customer_no_temp_,1,INSTR(customer_no_temp_,'@')-1) ;
   
         ship_addr_no_     := '000';
         bill_addr_no_     := '000';
   
         obj_value_json := obj1_.get('increment_id');
         increment_id_ := obj_value_json.get_string;    
   
         obj_value_json := obj1_.get('condicao_frete');
         delivery_terms_ := obj_value_json.get_string;        
   
         IF obj1_.exist('transportadora_codigo') THEN
            obj_value_json := obj1_.get('transportadora_codigo');
            forward_agent_id_ := obj_value_json.get_string;  
         END IF;
   
         obj_value_json := obj1_.get('base_shipping_amount');
         dbms_output.put_line('total_shipping_highlighted_: ' || obj_value_json.get_string); 
         total_shipping_highlighted_ := obj_value_json.get_string;        
   
         IF  total_shipping_highlighted_ > 0 THEN 
            c_not_highlight_freight_ := 'FALSE';
         ELSE 
            c_not_highlight_freight_ := 'TRUE';               
         END IF;
   
         ship_via_code_ := 'TR';
   
         IF obj1_.exist('vendedor_codigo') THEN
            obj_value_json := obj1_.get('vendedor_codigo');
            salesman_attendant_:=  obj_value_json.get_string;    
         END IF;
   
         contract_stock_    := NULL;
         contract_sales_    := NULL;
         price_list_no_     := NULL;
         pay_term_id_       := NULL;
   
         IF obj1_.exist('additional_data') THEN 
            json_detalhe_ov_ := pljson(obj1_.get('additional_data'));
            obj_value_json := json_detalhe_ov_.get('order_type_stock');
            contract_stock_ := obj_value_json.get_string;
            obj_value_json := json_detalhe_ov_.get('order_type_nf_issuer');
            contract_sales_ := obj_value_json.get_string;
            obj_value_json := json_detalhe_ov_.get('order_type_price_list_id');
            price_list_no_ := obj_value_json.get_string;
            obj_value_json := json_detalhe_ov_.get('payment_conditions_condition');
            pay_term_id_ := obj_value_json.get_string;
   
            IF json_detalhe_ov_.exist('note_obs') THEN
               obj_value_json := json_detalhe_ov_.get('note_obs');
               obs_nf_ := obj_value_json.get_string;
            END IF;
   
            IF json_detalhe_ov_.exist('order_obs') THEN
               obj_value_json := json_detalhe_ov_.get('order_obs');
               obs_pedido_ := obj_value_json.get_string;
            END IF;
   
            IF json_detalhe_ov_.exist('buy_order') THEN
               obj_value_json := json_detalhe_ov_.get('buy_order');
               num_oc_cliente_ := obj_value_json.get_string;
            END IF;
   
         END IF;
   
         IF contract_stock_ = contract_sales_ THEN
            type_order_           := 'NO';
            inter_site_operation_ := 'FALSE';
         ELSE
            type_order_           := 'OIS';        
            inter_site_operation_ := 'TRUE';
         END IF;
         operation_id_:= NULL;
         operation_id_ := get_operacao_fiscal(customer_no_, contract_stock_, contract_sales_, price_list_no_ );
   
         dbms_output.put_line('---------------cabecalho da ordem de venda---------');
         dbms_output.put_line('increment_id_ - ' ||increment_id_);
         dbms_output.put_line('entity_id_ - ' ||entity_id_);
         dbms_output.put_line('site_estoque_ - ' || contract_stock_);
         dbms_output.put_line('site_venda_ - ' || contract_sales_);
         dbms_output.put_line('tipo_ordem_ - ' || type_order_);
         dbms_output.put_line('customer_no_ - ' ||  customer_no_);
         dbms_output.put_line('flag_ios_ - ' ||  inter_site_operation_);
         dbms_output.put_line('tipo_ordem_ - ' || type_order_);
         dbms_output.put_line('cond_pagto_ - ' ||pay_term_id_);
         dbms_output.put_line('cod_entrega_ - ' ||delivery_terms_);
         dbms_output.put_line('id_tranportadora_ - ' ||forward_agent_id_);
         dbms_output.put_line('cod_vendedor_ - ' ||salesman_attendant_);
   
         -- itens da ordem de venda
         dbms_output.put_line('---------------itens da ordem de venda---------');      
         json_ordens_itens_ := pljson_ext.get_json_list(obj1_, 'items');
         FOR b IN 1 .. json_ordens_itens_.count LOOP
            obj2_ :=  pljson(json_ordens_itens_.get(b));
   
            obj_value_json := obj2_.get('item_id');
            item_id_ := obj_value_json.get_string;
   
            obj_value_json := obj2_.get('sku');
            sku_ := obj_value_json.get_string;
            part_no_ := SUBSTR(sku_,2);
            IF LENGTH(part_no_) < 7 THEN
               part_no_ := substr(part_no_, 1, 2)|| RPAD(' ', 7-LENGTH(part_no_))||substr(part_no_, 3);
            END IF;
            obj_value_json := obj2_.get('qty_ordered');
            buy_qty_due_ := obj_value_json.get_string;
            obj_value_json := obj2_.get('price');
            sale_unit_price_ := obj_value_json.get_string;
   
            obj_value_json := obj2_.get('original_price');
            sale_unit_price_original_ := obj_value_json.get_string;
   
            discount_perc_calc_:= 0;
            sale_unit_price_original_ :=0;
   
            IF obj2_.exist('additional_data') THEN
               json_item_dados_ := pljson(obj2_.get('additional_data'));
               IF json_item_dados_.exist('tax_data') THEN
                  json_item_impostos_ := pljson(json_item_dados_.get('tax_data'));
                  obj_value_json := json_item_impostos_.get('ipi');
                  ipi_percentage_ := obj_value_json.get_string;
               END IF;   
            END IF;
   
            dbms_output.put_line('codigo_produto_ - ' || part_no_);
            dbms_output.put_line('quantidade_ - ' || buy_qty_due_);
            dbms_output.put_line('preco_venda_ - ' || sale_unit_price_);
            dbms_output.put_line('aliquota_ipi_ - ' || ipi_percentage_);
   
            BEGIN
   
               info_ := NULL;
               objid_ := NULL;
               objversion_ := NULL;
               Client_sys.Clear_attr(attr_);
               -- Client_SYS.Add_To_Attr('ID_QUOTATION_IFS', NULL  , attr_);
               -- Client_SYS.Add_To_Attr('ID_ORDER_IFS', NULL , attr_);
               Client_SYS.Add_To_Attr('ENTITY_ID', entity_id_ , attr_);
               Client_SYS.Add_To_Attr('QUOTE_ID', quote_id_ , attr_);
               Client_SYS.Add_To_Attr('INCREMENT_ID', increment_id_ , attr_);
               Client_SYS.Add_To_Attr('CONTRACT_STOCK', contract_stock_ , attr_);
               Client_SYS.Add_To_Attr('CONTRACT_SALES', contract_sales_, attr_);
               Client_SYS.Add_To_Attr('TYPE_ORDER', type_order_ , attr_);
               Client_SYS.Add_To_Attr('INTER_SITE_OPERATION', inter_site_operation_ , attr_);
               Client_SYS.Add_To_Attr('OPERATION_ID', operation_id_ , attr_);
               Client_SYS.Add_To_Attr('PAY_TERM_ID', pay_term_id_, attr_);
               Client_SYS.Add_To_Attr('DELIVERY_TERMS', delivery_terms_ , attr_);
               Client_SYS.Add_To_Attr('CUSTOMER_NO', customer_no_ , attr_);
               Client_SYS.Add_To_Attr('SHIP_ADDR_NO', ship_addr_no_ , attr_);
               Client_SYS.Add_To_Attr('BILL_ADDR_NO', bill_addr_no_ , attr_);
               Client_SYS.Add_To_Attr('SHIP_VIA_CODE', ship_via_code_ , attr_);
               Client_SYS.Add_To_Attr('FORWARD_AGENT_ID', forward_agent_id_, attr_);
               Client_SYS.Add_To_Attr('TOTAL_SHIPPING_HIGHLIGHTED', total_shipping_highlighted_ , attr_);
               Client_SYS.Add_To_Attr('C_NOT_HIGHLIGHT_FREIGHT', c_not_highlight_freight_ , attr_);
               Client_SYS.Add_To_Attr('SALESMAN_ATTENDANT', salesman_attendant_, attr_);
               Client_SYS.Add_To_Attr('PRICE_LIST_NO', price_list_no_ , attr_);
               Client_SYS.Add_To_Attr('ITEM_ID', item_id_ , attr_);
               Client_SYS.Add_To_Attr('SKU', sku_, attr_);
               Client_SYS.Add_To_Attr('PART_NO', part_no_ , attr_);
               Client_SYS.Add_To_Attr('BUY_QTY_DUE', buy_qty_due_ , attr_);
               Client_SYS.Add_To_Attr('SALE_UNIT_PRICE', sale_unit_price_ , attr_);
               Client_SYS.Add_To_Attr('SALE_UNIT_PRICE_ORIGINAL', sale_unit_price_original_ , attr_);
               Client_SYS.Add_To_Attr('DISCOUNT_PERC_CALC', discount_perc_calc_ , attr_);
               Client_SYS.Add_To_Attr('IPI_PERCENTAGE', ipi_percentage_ , attr_);
               -- Client_SYS.Add_To_Attr('STATUS_ORDER_IFS', NULL, attr_);
               Client_SYS.Add_To_Attr('OBS_NF', obs_nf_, attr_);
               Client_SYS.Add_To_Attr('OBS_PEDIDO', obs_pedido_, attr_);
               Client_SYS.Add_To_Attr('NUM_OC_CLIENTE', num_oc_cliente_, attr_);
               C_INT_MAG_CONSUMER_ORDER_API.NEW__(info_, objid_, objversion_, attr_, 'DO');
               
            EXCEPTION 
               WHEN OTHERS THEN
                  DBMS_OUTPUT.PUT_LINE( 'ERRO INTEGRACAO PEDIDO MAGENTO' || increment_id_ || '-CODIGO ERRO-'||SQLCODE||' -ERROR DESCR- '||SQLERRM);
            END;              
         END LOOP;
   
         dbms_output.put_line('---------------Fim do Pedido ---------');   
      END LOOP;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Dados_Pedido_Consumer');
   Cust(token_, host_name_);
END Execute_Dados_Pedido_Consumer;


FUNCTION get_existe_ov_consumer(entity_id_ NUMBER) RETURN NUMBER
IS
   
   FUNCTION Cust(entity_id_ NUMBER) RETURN NUMBER
   IS
      exist_ NUMBER;
      
      CURSOR get_existe_id_ (entity_id__ NUMBER)IS SELECT COUNT(*)
                                                 FROM C_INT_MAG_CONSUMER_ORDER_TAB
                                                 WHERE entity_id = entity_id__;
   BEGIN
      
      OPEN   get_existe_id_(entity_id_);
      FETCH  get_existe_id_ INTO  exist_;
      CLOSE  get_existe_id_;
   
      IF NVL(exist_,0) = 0 THEN
         RETURN  0;
      ELSE   
         RETURN  1;
      END IF;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_existe_ov_consumer');
   RETURN Cust(entity_id_);
END get_existe_ov_consumer;


FUNCTION get_ordem_magento_por_id (token_ IN VARCHAR2, host_name_ IN VARCHAR2) RETURN CLOB
IS
   
   FUNCTION Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2) RETURN CLOB
   IS
      
      
      l_clob_request  CLOB;
      l_clob_response CLOB;
      endPoint_       VARCHAR2(32000);
      error_status_  VARCHAR2(32000);
            
      BEGIN
               
         endPoint_ := '/rest/consumer_maxprint/V1/getAvailableOrders';
         l_clob_request:= '';
         Execute_Json(token_, host_name_, endPoint_, 'GET', l_clob_request, l_clob_response, error_status_);
         
         IF error_status_ = 'FALSE' THEN
            RETURN l_clob_response;      
         ELSE
            Gravar_Log_Trigger(USER,  'ERROR get_cliente_existe_magento: '||substr(l_clob_response,1,1600));
            RETURN 'ERRO';
         END IF;   
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_ordem_magento_por_id');
   RETURN Cust(token_, host_name_);
END get_ordem_magento_por_id;


FUNCTION get_qtd_estoque (part_no_ IN VARCHAR2, contract_ IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (part_no_ IN VARCHAR2, contract_ IN VARCHAR2) RETURN NUMBER
   IS
      
      qtd_disp_ NUMBER;
      
      CURSOR get_estoque (part_no__ IN VARCHAR2, contract__ IN VARCHAR2) 
                          IS  SELECT SUM(I.QTY_ONHAND - I.QTY_RESERVED)
                              FROM   INVENTORY_PART_IN_STOCK_UIV I, WAREHOUSE_BAY_BIN W
                              WHERE NVL(I.AVAILABILITY_CONTROL_ID,' ') = ' '  
                                    AND I.LOCATION_TYPE_DB IN ('PICKING','DEEP')
                                    AND I.LOCATION_NO = W.LOCATION_NO
                                    AND I.CONTRACT = W.CONTRACT
                                    AND Warehouse_API.Get_Remote_Warehouse_Db(I.CONTRACT,W.WAREHOUSE_ID) = 'FALSE'
                                    AND I.CONTRACT = contract__ 
                                    AND I.PART_NO = part_no__;
      
   BEGIN
     
     OPEN get_estoque(part_no_, contract_);
     FETCH get_estoque INTO qtd_disp_ ;
     CLOSE get_estoque;
     qtd_disp_:= NVL(qtd_disp_,0);          
   
     RETURN qtd_disp_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_qtd_estoque');
   RETURN Cust(part_no_, contract_);
END get_qtd_estoque;


FUNCTION get_lista_preco_frete (contract_          IN VARCHAR2,
                                ship_via_code_      IN VARCHAR2, 
                                freight_map_id_     IN VARCHAR2, 
                                forward_agent_id_   IN VARCHAR2,
                                use_price_incl_tax_ IN VARCHAR2,
                                vendor_no_          IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (contract_          IN VARCHAR2,
                                   ship_via_code_      IN VARCHAR2, 
                                   freight_map_id_     IN VARCHAR2, 
                                   forward_agent_id_   IN VARCHAR2,
                                   use_price_incl_tax_ IN VARCHAR2,
                                   vendor_no_          IN VARCHAR2) RETURN VARCHAR2
   IS                               
       lista_preco_frete_  ORDER_QUOTATION.freight_price_list_no%TYPE;
   
   BEGIN
       IFSRIB.Language_SYS.Set_Language('bp');
       
       IF (vendor_no_ IS NOT NULL) THEN 
           lista_preco_frete_ := IFSRIB.Freight_Price_List_Direct_API.Get_Active_Freight_List_No(contract_ , ship_via_code_ , freight_map_id_ , forward_agent_id_ , use_price_incl_tax_ , vendor_no_ );
       ELSE
            lista_preco_frete_ := IFSRIB.Freight_Price_List_Base_API.Get_Active_Freight_List_No(contract_ , ship_via_code_ , freight_map_id_ , forward_agent_id_ , use_price_incl_tax_ );
       END IF;
   
       RETURN lista_preco_frete_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_lista_preco_frete');
   RETURN Cust(contract_, ship_via_code_, freight_map_id_, forward_agent_id_, use_price_incl_tax_, vendor_no_);
END get_lista_preco_frete;


PROCEDURE Create_Quotation_Freight (quotation_no_ IN VARCHAR2)
IS
   
   PROCEDURE Cust (quotation_no_ IN VARCHAR2)
       
   IS
   
       info_              VARCHAR2(32000);
       objid_             VARCHAR2(32000);
       objversion_        VARCHAR2(32000);
       attr_              VARCHAR2(32000);
       lista_preco_frete_ ORDER_QUOTATION.freight_price_list_no%TYPE;
       
       contract_           ORDER_QUOTATION.contract%TYPE;
       ship_via_code_      ORDER_QUOTATION.ship_via_code%TYPE;
       freight_map_id_     ORDER_QUOTATION.freight_map_id%TYPE; 
       forward_agent_id_   ORDER_QUOTATION.forward_agent_id%TYPE; 
       use_price_incl_tax_ ORDER_QUOTATION.use_price_incl_tax_db%TYPE; 
       vendor_no_          ORDER_QUOTATION.vendor_no%TYPE; 
       
       CURSOR get_cot (quotation_no__ IN VARCHAR2) IS SELECT a.objid, 
                                                             a.objversion,
                                                             a.contract,
                                                             a.ship_via_code,
                                                             a.freight_map_id,
                                                             a.forward_agent_id,
                                                             a.use_price_incl_tax_db,
                                                             a.vendor_no
                                                             
                                                      FROM ORDER_QUOTATION a
                                                      WHERE  a.quotation_no = quotation_no__;                                               
   
   BEGIN
      info_        := NULL;
      OPEN get_cot(quotation_no_);
      FETCH get_cot INTO objid_, objversion_, contract_, ship_via_code_, freight_map_id_, forward_agent_id_, use_price_incl_tax_, vendor_no_;
         IF get_cot%FOUND THEN
           lista_preco_frete_ := get_lista_preco_frete(contract_ , 
                                                       ship_via_code_, 
                                                       freight_map_id_, 
                                                       forward_agent_id_, 
                                                       use_price_incl_tax_, 
                                                       vendor_no_);
   
           attr_        := 'FREIGHT_PRICE_LIST_NO'||chr(31)||lista_preco_frete_ ||chr(30);
           IFSRIB.ORDER_QUOTATION_API.MODIFY__( info_ , objid_ , objversion_ , attr_ , 'DO' );
           info_        := NULL;
           IFSRIB.Customer_Order_Charge_Util_API.Calc_Consolidate_Charges(info_ , quotation_no_);
   
         END IF;
      CLOSE get_cot;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Create_Quotation_Freight');
   Cust(quotation_no_);
END Create_Quotation_Freight;


PROCEDURE get_valor_frete (contract_           IN  VARCHAR2,
                            id_ibege_          IN  NUMBER, 
                            cubed_weight_      IN  NUMBER,
                            value_total_gross_ IN  NUMBER,                                    
                            forwarder_ID_      OUT VARCHAR2, 
                            day_delivery_      OUT NUMBER,
                            value_freight_     OUT NUMBER)
IS
   
   PROCEDURE Cust (contract_           IN  VARCHAR2,
                               id_ibege_          IN  NUMBER, 
                               cubed_weight_      IN  NUMBER,
                               value_total_gross_ IN  NUMBER,                                    
                               forwarder_ID_      OUT VARCHAR2, 
                               day_delivery_      OUT NUMBER,
                               value_freight_     OUT NUMBER)
   IS
   
      list_price_freight_no_       FREIGHT_PRICE_LIST.price_list_no%TYPE;
      ship_via_code_               FREIGHT_PRICE_LIST.ship_via_code%TYPE;
      freight_map_id_              FREIGHT_PRICE_LIST.freight_map_id%TYPE;   
   
      CURSOR get_forwarder (contract__          IN  VARCHAR2, 
                            id_ibege__          IN  NUMBER, 
                            cubed_weight__      IN  NUMBER,
                            value_total_gross__ IN  NUMBER,
                            ship_via_code__     IN  VARCHAR2, 
                            freight_map_id__    IN  VARCHAR2
                            )
             IS 
             
             SELECT * FROM (
             
             SELECT  A.FORWARDER_ID,
                           A.NAME,
                           A.ASSOCIATION_NO,
                           A.C_NOTFIS_FILE,
                           A.C_AGGREGATE,
                           A.C_CUBED_WEIGHT_FREIGHT,
                           A.C_ICMS_OVER_I_P_FREIGHT,
                           A.C_KILOGRAM_FRACTION,
                           A.C_TOLL_TYPE,
                           A.C_INTERNAL_FORWARDER,
                           A.C_SITE_FORWARDER,
                           A.C_INTER_SITE_OPERATION,
                           A.C_MULTI_OPERATION,
                           NVL(get_total_freight(ifsrib.Freight_Price_List_Base_API.Get_Active_Freight_List_No(contract__,
                                                                                                    ship_via_code__,
                                                                                                    freight_map_id__,
                                                                                                    A.FORWARDER_ID,
                                                                                                    'FALSE',
                                                                                                    NULL),
                                                             cubed_weight__,
                                                             value_total_gross__,
                                                             id_ibege__,
                                                             freight_map_id__,
                                                             A.FORWARDER_ID),9999999999999) AS TOT_FREIGHT,
                                           
                                           (select lead.delivery_time
                                              from C_FORWARDER_INFO_LEAD_TIME lead
                                             where lead.contract = contract__
                                               and lead.ibge_id = id_ibege__
                                               and lead.forwarder_id = a.forwarder_id) as DELIVERY_TIME
   
                            FROM FORWARDER_INFO A
                            WHERE a.forwarder_id IN
                                  (select lead.forwarder_id
                                     from C_FORWARDER_INFO_LEAD_TIME lead
                                    where lead.contract = contract__
                                      and lead.ibge_id = id_ibege__)
   ) ORDER BY TOT_FREIGHT FETCH FIRST 1 ROW ONLY
                               ;
   
   BEGIN
       
      ship_via_code_  := 'TR';
      freight_map_id_ := 'T_RODOVIARIO';
      
      FOR get_ IN  get_forwarder (contract_, 
                                  id_ibege_, 
                                  cubed_weight_,
                                  value_total_gross_,
                                  ship_via_code_,  
                                  freight_map_id_) LOOP
       
          forwarder_ID_ := get_.FORWARDER_ID;
          day_delivery_ := get_.DELIVERY_TIME;
          value_freight_ := get_.TOT_FREIGHT;
   
       END LOOP;   
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_valor_frete');
   Cust(contract_, id_ibege_, cubed_weight_, value_total_gross_, forwarder_ID_, day_delivery_, value_freight_);
END get_valor_frete;


FUNCTION get_total_freight(price_list_no_      IN VARCHAR2,
                           cubed_weight_       IN NUMBER,
                           value_total_gross_  IN NUMBER,
                           id_ibege_           IN NUMBER,
                           id_map_freight_     IN VARCHAR2,
                           forwarder_id_       IN VARCHAR2
                           
                           ) RETURN NUMBER
IS
   
   FUNCTION Cust(price_list_no_      IN VARCHAR2,
                              cubed_weight_       IN NUMBER,
                              value_total_gross_  IN NUMBER,
                              id_ibege_           IN NUMBER,
                              id_map_freight_     IN VARCHAR2,
                              forwarder_id_       IN VARCHAR2
                              
                              ) RETURN NUMBER
   IS    
      value_total_freight_       NUMBER;
      value_scalonated_          NUMBER;
      value_ad_valorem_          NUMBER;
      value_gris_                NUMBER;
      value_toll_                NUMBER;
      value_dispatch_tax_        NUMBER;
      value_trt_                 NUMBER;
      value_additional_by_kilo_  NUMBER; 
      value_encargos_            NUMBER;  
      qtd_min_                   NUMBER;
      
   BEGIN
   
      qtd_min_ := get_qtd_min_(price_list_no_,
                               cubed_weight_,
                               id_ibege_,
                               id_map_freight_);
   
       value_scalonated_ := get_valor_scalonated(price_list_no_,
                                                   cubed_weight_,
                                                   qtd_min_,
                                                   value_total_gross_,
                                                   id_ibege_,
                                                   id_map_freight_);
                                           
      value_ad_valorem_ := get_valor_ad_valorem(price_list_no_,
                                               cubed_weight_,
                                               qtd_min_,
                                               value_total_gross_,
                                               id_ibege_,
                                               id_map_freight_);
                                           
      value_gris_ := get_valor_gris(price_list_no_,
                                   cubed_weight_,
                                   qtd_min_,
                                   value_total_gross_,
                                   id_ibege_,
                                   id_map_freight_);
   
      value_toll_ := get_valor_toll(price_list_no_,
                                   cubed_weight_,
                                   qtd_min_,
                                   value_total_gross_,
                                   id_ibege_,
                                   id_map_freight_,
                                   forwarder_id_);
   
      value_dispatch_tax_ := get_valor_dispatch_tax(price_list_no_,
                                           cubed_weight_,
                                           qtd_min_,
                                           value_total_gross_,
                                           id_ibege_,
                                           id_map_freight_);
      
      value_trt_ := get_valor_trt(price_list_no_,
                                           cubed_weight_,
                                           qtd_min_,
                                           value_total_gross_,
                                           id_ibege_,
                                           id_map_freight_);
   
      value_additional_by_kilo_:= get_valor_additional_by_kilo_(price_list_no_,
                                                           cubed_weight_,
                                                           qtd_min_,
                                                           value_total_gross_,
                                                           id_ibege_,
                                                           id_map_freight_);                                        
   
   
       value_encargos_ := get_sales_price(price_list_no_,
                                           cubed_weight_,
                                           qtd_min_,
                                           id_ibege_,
                                           id_map_freight_); 
   
      value_total_freight_ := ROUND(value_scalonated_ 
                                      + value_ad_valorem_ 
                                      + value_gris_ 
                                      + value_toll_ 
                                      + value_dispatch_tax_ 
                                      + value_trt_
                                      + value_additional_by_kilo_
                                      + value_encargos_,2);
             
      RETURN value_total_freight_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_total_freight');
   RETURN Cust(price_list_no_, cubed_weight_, value_total_gross_, id_ibege_, id_map_freight_, forwarder_id_);
END get_total_freight;


FUNCTION get_valor_scalonated (price_list_no_      IN VARCHAR2,
                               cubed_weight_       IN NUMBER,
                               qtd_min_            IN NUMBER,                               
                               value_total_gross_  IN NUMBER,
                               id_ibege_           IN NUMBER,
                               id_map_freight_     IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_      IN VARCHAR2,
                                  cubed_weight_       IN NUMBER,
                                  qtd_min_            IN NUMBER,                               
                                  value_total_gross_  IN NUMBER,
                                  id_ibege_           IN NUMBER,
                                  id_map_freight_     IN VARCHAR2) RETURN NUMBER
   IS    
      value_ NUMBER;
      value_minimum_  NUMBER;
      
   BEGIN
   
      value_ := NVL(Freight_Price_List_Line_API.Get_C_Valid_Charge_Scal(price_list_no_,
                                                                         qtd_min_,
                                                                         0,
                                                                         sysdate,
                                                                         id_map_freight_,
                                                                         id_ibege_),0);
   
      value_minimum_ := NVL(Freight_Price_List_Zone_API.Get_Min_Freight_Amount(price_list_no_, id_map_freight_, id_ibege_),0);                                                                         
   
      IF value_minimum_ > value_  THEN
          value_ := value_minimum_;
      END IF;
                                                                       
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_valor_scalonated');
   RETURN Cust(price_list_no_, cubed_weight_, qtd_min_, value_total_gross_, id_ibege_, id_map_freight_);
END get_valor_scalonated;


FUNCTION get_valor_ad_valorem (price_list_no_      IN VARCHAR2,
                               cubed_weight_       IN NUMBER,
                               qtd_min_            IN NUMBER,
                               value_total_gross_  IN NUMBER,
                               id_ibege_           IN NUMBER,
                               id_map_freight_     IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_      IN VARCHAR2,
                                  cubed_weight_       IN NUMBER,
                                  qtd_min_            IN NUMBER,
                                  value_total_gross_  IN NUMBER,
                                  id_ibege_           IN NUMBER,
                                  id_map_freight_     IN VARCHAR2) RETURN NUMBER
   IS    
      value_          NUMBER;
      value_minimum_  NUMBER;
      
   BEGIN
   
      value_ := value_total_gross_ * Freight_Price_List_Line_API.Get_C_Ad_Valorem_Cust(price_list_no_,
                                                                                       qtd_min_,
                                                                                       sysdate,
                                                                                       id_map_freight_,
                                                                                       id_ibege_);
                                                                                       
      value_minimum_ := NVL(Freight_Price_List_Zone_API.Get_C_Minimum_Ad_Valorem_Value(price_list_no_, id_map_freight_, id_ibege_),0);                                                                         
   
      IF value_minimum_ > value_  THEN
          value_ := value_minimum_;
      END IF;
                                                                                    
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_valor_ad_valorem');
   RETURN Cust(price_list_no_, cubed_weight_, qtd_min_, value_total_gross_, id_ibege_, id_map_freight_);
END get_valor_ad_valorem;


FUNCTION get_valor_gris (price_list_no_            IN VARCHAR2,
                               cubed_weight_       IN NUMBER,
                               qtd_min_            IN NUMBER,
                               value_total_gross_  IN NUMBER,
                               id_ibege_           IN NUMBER,
                               id_map_freight_     IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_            IN VARCHAR2,
                                  cubed_weight_       IN NUMBER,
                                  qtd_min_            IN NUMBER,
                                  value_total_gross_  IN NUMBER,
                                  id_ibege_           IN NUMBER,
                                  id_map_freight_     IN VARCHAR2) RETURN NUMBER
   IS    
      value_          NUMBER;
      value_minimum_  NUMBER;
      
   BEGIN
   
      value_ := value_total_gross_ * NVL(Freight_Price_List_Line_API.Get_C_Gris_Cust(price_list_no_,
                                                                                           qtd_min_,
                                                                                           sysdate,
                                                                                           id_map_freight_,
                                                                                           id_ibege_),0);
                                                                                           
      value_minimum_ := NVL(Freight_Price_List_Zone_API.Get_C_Minimum_Gris_Value(price_list_no_, id_map_freight_, id_ibege_),0);
   
      IF value_minimum_ > value_  THEN
          value_ := value_minimum_;
      END IF;
                                                                                           
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_valor_gris');
   RETURN Cust(price_list_no_, cubed_weight_, qtd_min_, value_total_gross_, id_ibege_, id_map_freight_);
END get_valor_gris;


FUNCTION get_valor_toll (price_list_no_      IN VARCHAR2,
                         cubed_weight_       IN NUMBER,
                         qtd_min_            IN NUMBER,                         
                         value_total_gross_  IN NUMBER,
                         id_ibege_           IN NUMBER,
                         id_map_freight_     IN VARCHAR2,
                         forwarder_id_       IN VARCHAR2
                         ) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_      IN VARCHAR2,
                            cubed_weight_       IN NUMBER,
                            qtd_min_            IN NUMBER,                         
                            value_total_gross_  IN NUMBER,
                            id_ibege_           IN NUMBER,
                            id_map_freight_     IN VARCHAR2,
                            forwarder_id_       IN VARCHAR2
                            ) RETURN NUMBER
   IS    
      value_             NUMBER;
      toll_              NUMBER;
      kilogram_fraction_ NUMBER;
      peso_              NUMBER;
      resto_divisao_     NUMBER;
      
       CURSOR get_f_mod(f_mod_ IN NUMBER) IS SELECT MOD(f_mod_,1) FROM   dual;
      
   BEGIN
   
      toll_ :=  NVL(Freight_Price_List_Line_API.Get_C_Toll_Cust(price_list_no_,
                                                                qtd_min_,
                                                                sysdate,
                                                                id_map_freight_,
                                                                id_ibege_),0);
                                                                                    
      kilogram_fraction_ := NVL(Forwarder_Info_API.Get_C_Kilogram_Fraction(forwarder_id_),0);                                                                                 
      
      IF Forwarder_Info_API.Get_C_Toll_Type_Db(forwarder_id_) = 'W' THEN
         value_ := toll_ * cubed_weight_;
      ELSE
          IF (toll_ != 0 AND kilogram_fraction_ != 0) THEN
           peso_ := (NVL(cubed_weight_,1) / kilogram_fraction_);
           resto_divisao_ := 0;
           OPEN get_f_mod(peso_);
           FETCH get_f_mod INTO resto_divisao_;
           CLOSE get_f_mod;
           IF resto_divisao_ > 0 THEN
                  value_ := (TRUNC(peso_)+1) * toll_;
            ELSE
                  value_ := TRUNC(peso_) * toll_;          
            END IF;
          END IF;
      END IF;
                                                                                    
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_valor_toll');
   RETURN Cust(price_list_no_, cubed_weight_, qtd_min_, value_total_gross_, id_ibege_, id_map_freight_, forwarder_id_);
END get_valor_toll;


FUNCTION get_valor_dispatch_tax (price_list_no_      IN VARCHAR2,
                                 cubed_weight_       IN NUMBER,
                                 qtd_min_            IN NUMBER,                                 
                                 value_total_gross_  IN NUMBER,
                                 id_ibege_           IN NUMBER,
                                 id_map_freight_     IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_      IN VARCHAR2,
                                    cubed_weight_       IN NUMBER,
                                    qtd_min_            IN NUMBER,                                 
                                    value_total_gross_  IN NUMBER,
                                    id_ibege_           IN NUMBER,
                                    id_map_freight_     IN VARCHAR2) RETURN NUMBER
   IS    
      value_ NUMBER;
      
   BEGIN
   
      value_ := NVL(Freight_Price_List_Line_API.Get_C_Dispatch_Tax_Cust( price_list_no_,
                                                                         qtd_min_,
                                                                         sysdate,
                                                                         id_map_freight_,
                                                                         id_ibege_),0);
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_valor_dispatch_tax');
   RETURN Cust(price_list_no_, cubed_weight_, qtd_min_, value_total_gross_, id_ibege_, id_map_freight_);
END get_valor_dispatch_tax;


FUNCTION get_valor_trt (price_list_no_      IN VARCHAR2,
                        cubed_weight_       IN NUMBER,
                        qtd_min_            IN NUMBER,                        
                        value_total_gross_  IN NUMBER,
                        id_ibege_           IN NUMBER,
                        id_map_freight_     IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_      IN VARCHAR2,
                           cubed_weight_       IN NUMBER,
                           qtd_min_            IN NUMBER,                        
                           value_total_gross_  IN NUMBER,
                           id_ibege_           IN NUMBER,
                           id_map_freight_     IN VARCHAR2) RETURN NUMBER
   IS    
      value_ NUMBER;
      
   BEGIN
   
      value_ := NVL(Freight_Price_List_Line_API.Get_C_Trt_Cust(price_list_no_,
                                                               qtd_min_,
                                                               sysdate,
                                                               id_map_freight_,
                                                               id_ibege_),0);
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_valor_trt');
   RETURN Cust(price_list_no_, cubed_weight_, qtd_min_, value_total_gross_, id_ibege_, id_map_freight_);
END get_valor_trt;


FUNCTION get_sales_price (price_list_no_      IN VARCHAR2,
                          cubed_weight_       IN NUMBER,
                          qtd_min_            IN NUMBER,                         
                          id_ibege_           IN NUMBER,
                          id_map_freight_     IN VARCHAR2
                         ) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_      IN VARCHAR2,
                             cubed_weight_       IN NUMBER,
                             qtd_min_            IN NUMBER,                         
                             id_ibege_           IN NUMBER,
                             id_map_freight_     IN VARCHAR2
                            ) RETURN NUMBER
   IS    
      value_             NUMBER;
      
   BEGIN
   
      value_ :=  cubed_weight_ * NVL(Freight_Price_List_Line_API.Get_C_Sales_Pice_Cust(price_list_no_,
                                                                                       qtd_min_,
                                                                                       sysdate,
                                                                                       id_map_freight_,
                                                                                       id_ibege_),0);
                                                                                   
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_sales_price');
   RETURN Cust(price_list_no_, cubed_weight_, qtd_min_, id_ibege_, id_map_freight_);
END get_sales_price;


FUNCTION get_existe_notif_cad_prod (cod_produto_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (cod_produto_ IN VARCHAR2) RETURN VARCHAR2
   IS
      CURSOR get_ (cod_produto__ IN VARCHAR2)IS SELECT CASE WHEN COUNT(*) > 0 THEN 'S' ELSE 'N' END AS existe_notif_cad_prod 
                                                FROM IFSRIB.C_MAGENTO_PV_CONSUMER_ACT A
                                                WHERE A.entity = 'PR' AND A.CODE = cod_produto__;
      exist_  VARCHAR2(1);                                                
   
   BEGIN
       
      OPEN   get_ (cod_produto_);
      FETCH  get_ INTO exist_;
      CLOSE  get_;
   
      RETURN exist_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_existe_notif_cad_prod');
   RETURN Cust(cod_produto_);
END get_existe_notif_cad_prod;


PROCEDURE Atualizar_Carteira_Cliente (customer_id_               IN VARCHAR2,
                                      business_unit_             IN VARCHAR2,
                                      vendor_id_                 IN VARCHAR2,
                                      vendor_id_new_             IN VARCHAR2)
IS
   
   PROCEDURE Cust (customer_id_               IN VARCHAR2,
                                         business_unit_             IN VARCHAR2,
                                         vendor_id_                 IN VARCHAR2,
                                         vendor_id_new_             IN VARCHAR2)
   
   IS
   
      portfolio_code_     C_Custumers_Port.portfolio_code%TYPE;
      portfolio_code_new_   C_Custumers_Port.portfolio_code%TYPE;
      all_customers_ VARCHAR2(100);
   
   
      CURSOR get_portfolio_ (salesman_attendant__  IN VARCHAR2, 
                             business_unit__       IN VARCHAR2) IS
                                                               SELECT b.portfolio_code
                                                               FROM  c_customer_portfolio b
                                                               WHERE b.vendor_id = salesman_attendant__
                                                               and b.business_unit = business_unit__;
   
       
   BEGIN
      
       all_customers_ := '11';
   
       OPEN   get_portfolio_ (vendor_id_, business_unit_ );
       FETCH  get_portfolio_ INTO portfolio_code_; 
       CLOSE  get_portfolio_;
       
       OPEN   get_portfolio_ (vendor_id_new_, business_unit_ );
       FETCH  get_portfolio_ INTO portfolio_code_new_; 
       CLOSE  get_portfolio_;
   
       IFSRIB.C_Custumers_Port_Api.Transfer_Port( portfolio_code_ , 
                                                  vendor_id_ , 
                                                  business_unit_ , 
                                                  customer_id_ , 
                                                  portfolio_code_new_ , 
                                                  vendor_id_new_ , 
                                                  business_unit_ , 
                                                  all_customers_ );
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Atualizar_Carteira_Cliente');
   Cust(customer_id_, business_unit_, vendor_id_, vendor_id_new_);
END Atualizar_Carteira_Cliente;


FUNCTION Check_carteira_cliente (customer_id_         IN VARCHAR2,
                                 salesman_attendant_  IN VARCHAR2,
                                 business_unit_       IN VARCHAR2
                                 ) RETURN VARCHAR2
IS
   
   FUNCTION Cust (customer_id_         IN VARCHAR2,
                                    salesman_attendant_  IN VARCHAR2,
                                    business_unit_       IN VARCHAR2
                                    ) RETURN VARCHAR2
   
   IS
       CURSOR get_ (customer_id__        IN VARCHAR2, 
                    salesman_attendant__ IN VARCHAR2,
                    business_unit__       IN VARCHAR2) IS SELECT CASE WHEN COUNT(*) > 0 THEN 'S' ELSE 'N' END AS exist
                                                           from  C_Custumers_Port a
                                                           where a.vendor_id = salesman_attendant__
                                                           AND A.business_unit = business_unit__
                                                           AND A.customer_id = customer_id__;
       exist_ VARCHAR2(1);                                                        
                                                           
   BEGIN
   
       OPEN   get_ (customer_id_, salesman_attendant_, business_unit_);
       FETCH  get_ INTO exist_;
       CLOSE  get_;
      
       RETURN exist_;
       
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Check_carteira_cliente');
   RETURN Cust(customer_id_, salesman_attendant_, business_unit_);
END Check_carteira_cliente;


FUNCTION  get_vendor_portfolio_default (customer_id_ IN VARCHAR2,  business_unit_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION  Cust (customer_id_ IN VARCHAR2,  business_unit_ IN VARCHAR2) RETURN VARCHAR2
       
   IS
      CURSOR rec_ (customer_id__ IN VARCHAR2,
                   business_unit__ IN VARCHAR2)IS SELECT a.vendor_id
                                                  FROM   C_CUSTOMER_PORT_OVERVIEW a
                                                  WHERE  a.customer_id = customer_id__
                                                         AND a.business_unit = business_unit__
                                                         AND a.portfolio_default = 'TRUE';
   
       salesman_attendant_   C_CUSTOMER_PORT_OVERVIEW.vendor_id%TYPE;                                                     
       
   BEGIN 
   
       OPEN   rec_ (customer_id_, business_unit_ );
       FETCH  rec_ INTO salesman_attendant_;
       CLOSE  rec_;
       
       RETURN salesman_attendant_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_vendor_portfolio_default');
   RETURN Cust(customer_id_, business_unit_);
END get_vendor_portfolio_default;


PROCEDURE Execute_Status_Ordem (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
IS
   
   PROCEDURE Cust (token_ IN VARCHAR2, host_name_ IN VARCHAR2)
   IS
   
       entity_id_       NUMBER;
       status_magento_  VARCHAR2(25);
       state_magento_   VARCHAR2(25);    
       handler_magento_ VARCHAR2(25);
       history_message_ VARCHAR2(100);
       order_no_if_     CUSTOMER_ORDER.order_no%TYPE;
       numero_nf_       FISCAL_NOTE.fiscal_note_no%TYPE;
       chave_danfe_     FISCAL_NOTE.fne_state_id%TYPE;
       fiscal_note_id_  FISCAL_NOTE.fiscal_note_id%TYPE;
       error_           VARCHAR2(5);    
   
       CURSOR get_ov IS SELECT DISTINCT a.id_quotation_ifs,
                                        a.id_order_ifs,
                                        a.entity_id,
                                        a.status_order_ifs
                         FROM C_INT_MAG_CONSUMER_ORDER_TAB a 
                         WHERE a.ID_ORDER_IFS IS NOT NULL 
                               AND NVL(a.status_order_ifs,'DUMMY') <> 'rb_invoiced';                                                            
                                      
   BEGIN
   
      FOR rec_ IN get_ov LOOP
         order_no_if_ := rec_.id_order_ifs;
         entity_id_   := rec_.entity_id; 
             
         -- primeiro status a ser enviado para portal de vendas
         IF rec_.status_order_ifs = 'rb_integrated_erp' THEN
            status_magento_  := 'rb_integrated_erp';
            state_magento_   := 'processing';
            handler_magento_ := 'status_update';
            fiscal_note_id_  := NULL;
            numero_nf_       := NULL;
            chave_danfe_     := NULL;
            history_message_ := 'Pedido integrado com ERP. Pedido gerado: ' || order_no_if_;
            Execute_Status_Ordem_Magento(token_, host_name_, entity_id_, status_magento_,state_magento_, handler_magento_, history_message_, order_no_if_,numero_nf_,chave_danfe_, error_);      
         END IF;
         status_magento_  := get_andamento_ordem_venda(order_no_if_);
             
         IF rec_.status_order_ifs <>  NVL(status_magento_,'dUMMy') or rec_.status_order_ifs = 'rb_billing' THEN
             state_magento_   := 'processing';
             handler_magento_ := 'status_update';
             fiscal_note_id_  := NULL;
             numero_nf_       := NULL;
             chave_danfe_     := NULL;
             history_message_ := convertToUnicode(get_mensagem_status_magento(order_no_if_, status_magento_));
             IF NVL(status_magento_,'dUMMy') =  'dUMMy' THEN
                CONTINUE;
             ELSIF status_magento_ = 'rb_invoiced' THEN
                handler_magento_ := 'processing';
                fiscal_note_id_ := get_fiscal_note_id(order_no_if_);
                numero_nf_      := NVL(FISCAL_NOTE_TEMP_API.Get_Fiscal_Note_No(fiscal_note_id_),FISCAL_NOTE_API.Get_Fiscal_Note_No(fiscal_note_id_));
                chave_danfe_    := NVL(FISCAL_NOTE_TEMP_API.Get_Fne_State_Id(fiscal_note_id_),FISCAL_NOTE_API.Get_Fne_State_Id(fiscal_note_id_));
             ELSIF  status_magento_ = 'canceled' THEN 
                state_magento_ := 'canceled';
                handler_magento_ := 'cancel';
                fiscal_note_id_  := NULL;
                numero_nf_       := NULL;
                chave_danfe_     := NULL;
             END IF;
             error_ := 'FALSE';
             Execute_Status_Ordem_Magento(token_, host_name_, entity_id_, status_magento_,state_magento_, handler_magento_, history_message_, order_no_if_,numero_nf_,chave_danfe_, error_);
                 
             IF error_ = 'FALSE' THEN
                UPDATE C_INT_MAG_CONSUMER_ORDER_TAB
                SET STATUS_ORDER_IFS = status_magento_
                WHERE  entity_id = entity_id_;
             END IF;
             
             IF status_magento_ = 'rb_invoiced' AND error_ = 'FALSE' THEN
                Execute_Enviar_Ordem_Magento(token_, host_name_, entity_id_,error_);
             END IF;
             
         END IF;
   
      END LOOP;
          
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Status_Ordem');
   Cust(token_, host_name_);
END Execute_Status_Ordem;


PROCEDURE Execute_Status_Ordem_Magento (token_           IN VARCHAR2,
                                        host_name_       IN VARCHAR2,
                                        entity_id_       IN NUMBER,
                                        status_magento_  IN VARCHAR2,
                                        state_magento_   IN VARCHAR2, 
                                        handler_magento_ IN VARCHAR2,
                                        history_message_ IN VARCHAR2, 
                                        order_no_if_     IN VARCHAR2,
                                        numero_nf_       IN VARCHAR2,
                                        chave_danfe_     IN VARCHAR2,
                                        error_           OUT VARCHAR2
                                        )
IS
   
   PROCEDURE Cust (token_           IN VARCHAR2,
                                           host_name_       IN VARCHAR2,
                                           entity_id_       IN NUMBER,
                                           status_magento_  IN VARCHAR2,
                                           state_magento_   IN VARCHAR2, 
                                           handler_magento_ IN VARCHAR2,
                                           history_message_ IN VARCHAR2, 
                                           order_no_if_     IN VARCHAR2,
                                           numero_nf_       IN VARCHAR2,
                                           chave_danfe_     IN VARCHAR2,
                                           error_           OUT VARCHAR2
                                           )
   IS
   
       l_clob_request   CLOB;
       l_clob_response  CLOB;
       endPoint_        VARCHAR2(100);
   
   BEGIN
         
   
         l_clob_request := '{"order": {';
         l_clob_request :=  l_clob_request || '"status": "' || status_magento_ || '"';
         l_clob_request :=  l_clob_request || ', "state": ' || '"' || state_magento_ || '"';
         l_clob_request :=  l_clob_request || ', "handler": ' || '"' || handler_magento_ || '"';   
         l_clob_request :=  l_clob_request || ', "history_message": ' || '"' || history_message_ || '"';         
         
         IF  NVL(order_no_if_,'dUMMy') <>  'dUMMy' THEN
            l_clob_request := l_clob_request  ||  ', "erp_identity": ' || '"' || order_no_if_ || '"';        
         END IF;
   
         IF  NVL(numero_nf_,'dUMMy') <>  'dUMMy' THEN
            l_clob_request := l_clob_request  ||  ', "nf": ' || '"' || numero_nf_ || '"';        
         END IF;
   
         IF  NVL(chave_danfe_,'dUMMy') <>  'dUMMy' THEN
            l_clob_request := l_clob_request  ||  ', "danfe": ' || '"' || chave_danfe_ || '"';        
         END IF;        
         l_clob_request :=  l_clob_request || '}}';
         
         endPoint_ := '/rest/all/V1/orderIntegrate/' || entity_id_;
         DBMS_OUTPUT.put_line('l_clob_request: ' || l_clob_request);
         DBMS_OUTPUT.put_line('endPoint_ :' || endPoint_);
         Execute_Json(token_, host_name_, endPoint_, 'POST', l_clob_request, l_clob_response, error_);
   
         IF error_ <> 'FALSE' THEN
            Gravar_Log_Trigger(USER,  'ERROR Execute_Status_Pedido: '|| substr(l_clob_response,1,1600));           
            -- Enviar_Email('ERROR Execute_Status_Pedido: '|| substr(l_clob_response,1,1600),'Magento Consumer - Erro - Atualizar Status Pedido');   
         END IF;
   
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Status_Ordem_Magento');
   Cust(token_, host_name_, entity_id_, status_magento_, state_magento_, handler_magento_, history_message_, order_no_if_, numero_nf_, chave_danfe_, error_);
END Execute_Status_Ordem_Magento;


PROCEDURE Execute_Enviar_Ordem_Magento (token_           IN VARCHAR2,
                                        host_name_       IN VARCHAR2,
                                        entity_id_       IN NUMBER,
                                        error_            OUT VARCHAR2)
IS
   
   PROCEDURE Cust (token_           IN VARCHAR2,
                                           host_name_       IN VARCHAR2,
                                           entity_id_       IN NUMBER,
                                           error_            OUT VARCHAR2)
       
   IS
      l_clob_request   CLOB;
      l_clob_response  CLOB;
      endPoint_        VARCHAR2(100);
   
   
   BEGIN    
   
      endPoint_ := '/rest/all/V1/order/' || entity_id_ || '/ship';
      l_clob_request := '';
      Execute_Json(token_, host_name_, endPoint_, 'POST', l_clob_request, l_clob_response, error_);
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Enviar_Ordem_Magento');
   Cust(token_, host_name_, entity_id_, error_);
END Execute_Enviar_Ordem_Magento;


PROCEDURE Execute_Cancel_Ordem_Magento (token_           IN VARCHAR2,
                                        host_name_       IN VARCHAR2,
                                        entity_id_       IN NUMBER,
                                        error_            OUT VARCHAR2)
IS
   
   PROCEDURE Cust (token_           IN VARCHAR2,
                                           host_name_       IN VARCHAR2,
                                           entity_id_       IN NUMBER,
                                           error_            OUT VARCHAR2)
       
   IS
   
   BEGIN    
   
      Execute_Status_Ordem_Magento (token_, 
                                    host_name_,
                                    entity_id_,
                                    'canceled',
                                    'canceled', 
                                    'cancel',
                                    'Ordem Venda Cancelada', 
                                    NULL,
                                    NULL,
                                    NULL,
                                    error_);
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'Execute_Cancel_Ordem_Magento');
   Cust(token_, host_name_, entity_id_, error_);
END Execute_Cancel_Ordem_Magento;


FUNCTION get_andamento_ordem_venda (order_no_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (order_no_ IN VARCHAR2) RETURN VARCHAR2
   IS
   
      status_       VARCHAR2(100);
      message_text_  CUSTOMER_ORDER_HISTORY.message_text%TYPE;
      
      CURSOR get_history (order_no__ IN VARCHAR2) IS SELECT *
                                                     FROM (SELECT message_text
                                                           FROM CUSTOMER_ORDER_HISTORY
                                                           WHERE ORDER_NO = order_no__
                                                           ORDER BY HISTORY_NO DESC)
                                                     WHERE ROWNUM = 1;
      
   BEGIN
      IF (order_no_ IS NULL) THEN
         RETURN NULL;
      END IF;
   
      OPEN  get_history (order_no_);
      FETCH get_history INTO message_text_;
      CLOSE get_history;
      
      message_text_ := UPPER(C_RB_UTIL_API.TIRA_ACENTOS(message_text_));
      
      
      status_:= CASE WHEN message_text_ LIKE '%BLOQUEADA%'               THEN 'rb_blocked' -- 'Analise de Credito'
                     WHEN message_text_ LIKE '%INFORMACAO CREDITO:%'     THEN 'rb_blocked' -- 'Analise de Credito'
                     WHEN message_text_ LIKE '%PICKLIST%'                THEN 'rb_picklist' -- 'Aguardando Separacao do Material'
                     WHEN message_text_ LIKE '%LIBERADO%'                THEN 'rb_reserve_stock' -- 'Falta reservar estoque'
                     WHEN message_text_ LIKE '%FOI SEPARADA%'            THEN 'rb_stock_conference' -- 'Aguardando Conferencia do Material pela Logistica'
                     WHEN message_text_ LIKE '%CONFERENCIA DE MATERIAL%' THEN 'rb_stock_conference' -- 'Aguardando Conferencia do Material pela Logistica'                         
                     WHEN message_text_ LIKE '%CONFERENCIA REALIZADA PARA LISTA DE SEPARACAO%' THEN 'rb_billing' -- 'Aguardando Conferencia do Material pela Logistica'                                                  
                     WHEN message_text_ LIKE '%NOTA FISCAL TEMPORARIA%'  THEN 'rb_billing' --'No Faturamento'
                     WHEN message_text_ LIKE '%TITULO CD%'               THEN 'rb_invoiced' --'Faturado'
                     WHEN message_text_ LIKE '%NOTA FISCAL FINAL%'       THEN 'rb_invoiced' --'Faturado'                         
                     WHEN message_text_ LIKE '%CANCELADA NA ORIGEM%'     THEN 'canceled' -- 'Cancelada'
                     WHEN message_text_ LIKE '%OS ENCARGOS DE FRETE FORAM CONSOLIDADOS%' 
                                      AND customer_order_api.Get_C_Inter_Site_Operation(order_no_) = 'TRUE' THEN NULL --'Em Transferencia Filial'
         ELSE NULL END;
         RETURN status_;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_andamento_ordem_venda');
   RETURN Cust(order_no_);
END get_andamento_ordem_venda;


FUNCTION get_mensagem_status_magento (order_no_ IN VARCHAR2, status_ IN VARCHAR2) RETURN VARCHAR2
IS
   
   FUNCTION Cust (order_no_ IN VARCHAR2, status_ IN VARCHAR2) RETURN VARCHAR2
   IS
   
      temp_ VARCHAR2(50);
   
   BEGIN
      
      temp_ := 'Pedido ' || order_no_ || ' ';    
      CASE WHEN status_ = 'rb_blocked'          THEN temp_ :=  temp_ || 'Analise de Credito';
           WHEN status_ = 'rb_picklist'         THEN temp_ :=  temp_ || 'Aguardando Separacao do Material';
           WHEN status_ = 'rb_reserve_stock'    THEN temp_ :=  temp_ || 'Falta reservar estoque';
           WHEN status_ = 'rb_stock_conference' THEN temp_ :=  temp_ || 'Aguardando Conferencia da Logistica';
           WHEN status_ = 'rb_billing'          THEN temp_ :=  temp_ || 'No Faturamento';
           WHEN status_ = 'rb_invoiced'         THEN temp_ :=  temp_ || 'Faturado';
           WHEN status_ = 'canceled'            THEN temp_ :=  temp_ || 'Cancelado';
           ELSE temp_ := NULL;
       END CASE;
   
       RETURN temp_;
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_mensagem_status_magento');
   RETURN Cust(order_no_, status_);
END get_mensagem_status_magento;


FUNCTION  get_fiscal_note_id (order_no_ IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION  Cust (order_no_ IN VARCHAR2) RETURN NUMBER
   IS
   
      fiscal_note_id_   FISCAL_NOTE.fiscal_note_id%TYPE;
      
      CURSOR get_nf_id (order_no__ IN VARCHAR2) IS SELECT a.FISCAL_NOTE_ID 
                                                   FROM C_MATERIAL_CONFERENCE a
                                                   WHERE a.ORDER_NO = order_no__;
   BEGIN 
      
      OPEN   get_nf_id(order_no_);
      FETCH  get_nf_id INTO fiscal_note_id_;
      CLOSE  get_nf_id; 
      
      RETURN fiscal_note_id_;
                                                   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_fiscal_note_id');
   RETURN Cust(order_no_);
END get_fiscal_note_id;


PROCEDURE get_info_lista_preco_web(customer_no_      IN VARCHAR2,
                                   price_list_no_    IN VARCHAR2, 
                                   id_operacao_      OUT NUMBER,
                                   sales_contract_   OUT VARCHAR2,
                                   stock_contract_   OUT VARCHAR2)
IS
   
   PROCEDURE Cust(customer_no_      IN VARCHAR2,
                                      price_list_no_    IN VARCHAR2, 
                                      id_operacao_      OUT NUMBER,
                                      sales_contract_   OUT VARCHAR2,
                                      stock_contract_   OUT VARCHAR2)
   IS
   
      CURSOR get_(customer_no__   IN VARCHAR2, 
                  price_list_no__ IN VARCHAR2) IS 
                                                  SELECT 
                                                     a.operation_id     AS id_operacao_,
                                                     a.operation_type   AS sales_contract_,
                                                     a.deposit_id       AS stock_contract_
                                                  FROM C_PRICE_LIST_AVAIL_WEB a
                                                  WHERE a.customer_id = customer_no__
                                                  AND a.price_list_no = price_list_no__
                                                  FETCH FIRST 1 ROWS ONLY;
   
       id_operacao__      C_PRICE_LIST_AVAIL_WEB.operation_id%TYPE;
       sales_contract__   C_PRICE_LIST_AVAIL_WEB.operation_type%TYPE;
       stock_contract__   C_PRICE_LIST_AVAIL_WEB.deposit_id%TYPE;
   
   BEGIN
   
      OPEN   get_(customer_no_, price_list_no_);
      FETCH  get_ INTO id_operacao__, sales_contract__, stock_contract__;
      CLOSE  get_; 
      
      id_operacao_     := id_operacao__;
      sales_contract_  := sales_contract__;
      stock_contract_  := stock_contract__;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_info_lista_preco_web');
   Cust(customer_no_, price_list_no_, id_operacao_, sales_contract_, stock_contract_);
END get_info_lista_preco_web;


PROCEDURE get_ID_Contato_Cliente (identity_ IN VARCHAR2, name_ IN VARCHAR2, external_id_ OUT NUMBER)
IS
   
   PROCEDURE Cust (identity_ IN VARCHAR2, name_ IN VARCHAR2, external_id_ OUT NUMBER)
   IS
     
      id_seq_      NUMBER;
      info_        VARCHAR2(32000);
      objid_       VARCHAR2(32000);
      objversion_  VARCHAR2(32000);
      attr_        VARCHAR2(32000);
      
      CURSOR get_exist_ (identity__ VARCHAR2, 
                         name__ VARCHAR2) IS SELECT SEQ
                                             FROM C_COMM_METHOD_CUST_ID_MAG_TAB A
                                             WHERE A.identity = identity__
                                                   AND A.NAME = name__;
   
   BEGIN  
   
      OPEN  get_exist_ (identity_,  name_);
      FETCH get_exist_ INTO id_seq_;
      CLOSE get_exist_;
      
      IF NVL(id_seq_,0) = 0 THEN
         Client_sys.Clear_attr(attr_);
         Client_SYS.Add_To_Attr('IDENTITY', identity_, attr_);
         Client_SYS.Add_To_Attr('NAME', name_, attr_);
   
         info_ := NULL;
         objid_ := NULL;
         objversion_ := NULL;
         C_COMM_METHOD_CUST_ID_MAG_API.NEW__( info_ , objid_ , objversion_ , attr_ , 'DO' );
         
         id_seq_ := Client_SYS.Get_Item_Value('SEQ', attr_);
      END IF;
     
      external_id_ := id_seq_;
      
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_ID_Contato_Cliente');
   Cust(identity_, name_, external_id_);
END get_ID_Contato_Cliente;


FUNCTION get_valor_additional_by_kilo_ (price_list_no_      IN VARCHAR2,
                                        cubed_weight_       IN NUMBER,
                                        qtd_min_            IN NUMBER,                                       
                                        value_total_gross_  IN NUMBER,
                                        id_ibege_           IN NUMBER,
                                        id_map_freight_     IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_      IN VARCHAR2,
                                           cubed_weight_       IN NUMBER,
                                           qtd_min_            IN NUMBER,                                       
                                           value_total_gross_  IN NUMBER,
                                           id_ibege_           IN NUMBER,
                                           id_map_freight_     IN VARCHAR2) RETURN NUMBER
   IS    
      value_             NUMBER;
      additional_weight_ NUMBER;
      
   BEGIN
   
      additional_weight_ := cubed_weight_ - qtd_min_;
    
      value_ := additional_weight_ * NVL(Freight_Price_List_Line_API.Get_C_Additional_By_Kilo_Cust( price_list_no_,
                                                                                                    qtd_min_,
                                                                                                    sysdate,
                                                                                                    id_map_freight_,
                                                                                                    id_ibege_),0);
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_valor_additional_by_kilo_');
   RETURN Cust(price_list_no_, cubed_weight_, qtd_min_, value_total_gross_, id_ibege_, id_map_freight_);
END get_valor_additional_by_kilo_;


FUNCTION get_qtd_min_ (price_list_no_      IN VARCHAR2,
                        cubed_weight_      IN NUMBER,
                        id_ibege_          IN NUMBER,
                        id_map_freight_    IN VARCHAR2) RETURN NUMBER
IS
   
   FUNCTION Cust (price_list_no_      IN VARCHAR2,
                           cubed_weight_      IN NUMBER,
                           id_ibege_          IN NUMBER,
                           id_map_freight_    IN VARCHAR2) RETURN NUMBER
   IS    
      value_ NUMBER;
      
      CURSOR get_ (price_list_no__      IN VARCHAR2,
                   cubed_weight__       IN NUMBER,
                   id_ibege__           IN NUMBER,
                   id_map_freight__     IN VARCHAR2) IS  SELECT min_qty
                                                         FROM   freight_price_list_line_tab
                                                         WHERE  price_list_no = price_list_no__
                                                                AND zone_id = id_ibege__
                                                                AND freight_map_id = id_map_freight__
                                                                AND valid_from <= SYSDATE
                                                                AND min_qty = (SELECT MAX(min_qty)
                                                                               FROM   FREIGHT_PRICE_LIST_LINE_TAB
                                                                               WHERE  price_list_no = price_list_no__
                                                                               AND    zone_id = id_ibege__
                                                                               AND    freight_map_id = id_map_freight__
                                                                               AND    min_qty <= cubed_weight__
                                                                               AND    valid_from <= SYSDATE)
                                                           GROUP BY min_qty;
              
      
   BEGIN
   
      OPEN  get_ (price_list_no_, cubed_weight_, id_ibege_, id_map_freight_);
      FETCH get_ INTO value_;
      CLOSE get_;
   
      value_ := NVL(value_,0);
      
      RETURN value_;
   
   END Cust;

BEGIN
   General_SYS.Init_Method(C_Int_Magento_Consu_Util_API.lu_name_, 'C_Int_Magento_Consu_Util_API', 'get_qtd_min_');
   RETURN Cust(price_list_no_, cubed_weight_, id_ibege_, id_map_freight_);
END get_qtd_min_;

-----------------------------------------------------------------------------
-------------------- FOUNDATION1 METHODS ------------------------------------
-----------------------------------------------------------------------------


--@IgnoreMissingSysinit
PROCEDURE Init
IS
   
   PROCEDURE Base
   IS
   BEGIN
      NULL;
   END Base;

BEGIN
   Base;
END Init;

BEGIN
   Init;
END C_Int_Magento_Consu_Util_API;
