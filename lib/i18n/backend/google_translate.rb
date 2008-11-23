require 'htmlentities'
require 'json'

module I18n
  module Backend
    class GoogleTranslate
      MATCH = /(\\\\)?\{\{([^\}]+)\}\}/
      
      @@google_translate_uri = URI.parse("http://ajax.googleapis.com/ajax/services/language/translate")
      GOOGLE_LANGUAGES = {
        'Arabic' => 'ar',  
        'Bulgarian' => 'bg',
        'Catalan' => 'ca',
        'Chinese (Simplified)' => 'zh-cn',
        'Chinese (Traditional)' => 'zh-tw',
        'Croatian' => 'hr',
        'Czech' => 'cs',
        'Danish' => 'da',        
        'Dutch' => 'nl',
        'English' => 'en',        
        'Filipino' => 'tl',
        'Finnish' => 'fi',
        'French' => 'fr',        
        'German' => 'de',
        'Greek' => 'el',       
        'Hebrew' => 'iw',
        'Hindi' => 'hi',        
        'Indonesian' => 'id',        
        'Italian' => 'it',
        'Japanese' => 'ja',        
        'Korean' => 'ko',
        'Latvian' => 'lv',
        'Lithuanian' => 'lt',        
        'Norwegian' => 'no',        
        'Polish' => 'pl',
        'Portuguese' => 'pt-pt',        
        'Romanian' => 'ro',
        'Russian' => 'ru',        
        'Slovak' => 'sk',
        'Slovenian' => 'sl',
        'Spanish' => 'es',       
        'Swedish' => 'sv',       
        'Ukrainian' => 'uk',
        'Vietnamese' => 'vi' }
      
        # Thanks for http://github.com/dookie/google-translate-api/
        def translate(locale, key, options = {})
          raise InvalidLocale.new(locale) if locale.nil?
          text = interpolate(locale, key.to_s, options)
          key = text.to_sym
          
          sl = I18n.default_locale
          tl = locale

          return text if sl == tl # default
          
          entry = lookup(locale, key)
          return entry if entry # cached
          
          params = { :langpair => "#{sl}|#{tl}", :q => text,
                     :v => 1.0 }.map { |k,v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')

          request = Net::HTTP.get(@@google_translate_uri.host, "#{@@google_translate_uri.path}?#{params}")
          coder = HTMLEntities.new
          
          if JSON.parse(request)['responseData']
            entry = coder.decode(JSON.parse(request)['responseData']['translatedText'])
            merge_translations( locale, { key => entry } )
            return entry # found
          else            
            return text # not found
          end
          
        end
        
        def localize(locale, object, format = :default)
          translate( locale, object.to_s )
        end        
      
        def reload!
          # must restart server
        end
        
        protected
          
          def translations
            @translations ||= {}
          end

          def interpolate(locale, string, values = {})
            return string unless string.is_a?(String)

            if string.respond_to?(:force_encoding)
              original_encoding = string.encoding
              string.force_encoding(Encoding::BINARY)
            end

            result = string.gsub(MATCH) do
              escaped, pattern, key = $1, $2, $2.to_sym

              if escaped
                pattern
              elsif !values.include?(key)
                raise MissingInterpolationArgument.new(pattern, string)
              else
                values[key].to_s
              end
            end

            result.force_encoding(original_encoding) if original_encoding
            result
          end
                    
          def lookup(locale, key, scope = [])
            return unless key
          
            keys = I18n.send(:normalize_translation_keys, locale, key, scope)
            keys.inject(translations) do |result, k|
              if (x = result[k.to_sym]).nil?
                return nil
              else
                x
              end
            end
          end
             
          def merge_translations(locale, data)
            locale = locale.to_sym
            translations[locale] ||= {}
            data = deep_symbolize_keys(data)

            # deep_merge by Stefan Rusterholz, see http://www.ruby-forum.com/topic/142809
            merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
            translations[locale].merge!(data, &merger)
          end

          # Return a new hash with all keys and nested keys converted to symbols.
          def deep_symbolize_keys(hash)
            hash.inject({}) { |result, (key, value)|
              value = deep_symbolize_keys(value) if value.is_a? Hash
              result[(key.to_sym rescue key) || key] = value
              result
            }
          end
                       
    end
  end
end
