# coding: UTF-8
%w[haml yaml].each {|r| require r}


def YAML.load_file( filepath )
	File.open( filepath, "r:utf-8" ) do |f|
		load( f )
	end
end

class TemplateJuggler

	# Экземпляр этого класса работает загрузчиком шаблонов, считая, что id шаблона соответствует именем файла
	# (с подкаталогами) внутри заданного каталога.
	class SimpleLoader
		attr_accessor :path
		def initialize path='./views'
			@path = path
		end
		def get_template id
			path = File.join(@path, "#{id}.haml")
			File::exists?(path) && File::readable?(path) ? File::open(path, 'r:utf-8') { |file| file.read } : nil
		end
		def get_locale lang, id
			lang = [lang.to_s] unless lang.is_a? Array
			locale_data = nil
			-> s {
				locale_data = lang.inject({}) do |acc,l|
					path = File.join(@path, "#{id}.#{l}.yaml")
					#data = File::exists?(path) && File::readable?(path) ? YAML.load_file( path ) : nil
					data = File::exists?(path) && File::readable?(path) ? File::open(path, 'r:utf-8') { |file| YAML.load file.read } : nil
					data.is_a?(Hash) ? data.merge(acc) : acc
				end unless locale_data
				locale_data[s.to_s] if locale_data
			}
		end
	end

	# Шаблоны обрабатываются в контексте объекта этого класса, если не задано иное.
	# Через переменные этого объекта шаблон может передать данные следующим шаблонам.
	class Scope
		# Сюда шаблон может записать (для TJ) id шаблона, который должен быть обработан следующим
		# (если не годится стандартный порядок -- с перемещением по каталогам снизу вверх
		# и использованием шаблонов autohandler)
		# !!! TJ пока не умеет обрабатывать относительный путь.
		attr_accessor :next_template
		# wrapper (обертка) -- тоже шаблон, если есть он должен быть применен к результату работы
		# текущего шаблона перед применением next_template.
		# Таким образом, один и тот же шаблон-wrapper может использоваться в нескольких иерархиях шаблонов.
		# !!! Не реализовано.
		attr_accessor :wrapper
		# Сюда TJ записывает id шаблона, который обрабатывается в настоящий момент
		# (на случай, если в процессе обработки шаблона понадобится его идентификатор).
		attr_accessor :current_template
		# Это если изнутри шаблона потребуется отрисовать другой шаблон
		attr_accessor :callback_machine
		attr_accessor :lang
		attr_accessor :locale
		def initialize machine=nil, args = {}
			@args = args
			@callback_machine = machine
		end
		def call id, args={}
			@callback_machine.render id, (@args.merge args) if callback_machine.respond_to?(:render)
		end
		def gettext s
			(@locale && @locale[s]) ? @locale[s] : s.to_s
		end
		alias_method :_, :gettext
	end

	# Объект, имеющий метод get и возвращающий шаблон по заданному id.
	# Для самой TJ не важно, где именно хранятся шаблоны. 
	attr_accessor :template_loader
	attr_accessor :locale_loader
	def initialize loader=nil, locale=nil
		@template_loader = template_loader || SimpleLoader.new
		@locale_loader = locale_loader || @template_loader
	end
	def render id, args={}
		id = id.to_s # id -- строка, имеющая вид полного пути ( "/aaa/bbb/ccc/fff" )
		id_a = id.split '/'
		base_a = id_a.dup
		base_a.pop
		scope = args[:scope] || Scope.new(self, args)
		scope.lang = args[:lang] if args[:lang]
		locals = args[:locals] || {}
		body = ''
		loop do
			id = id_a.join('/')
			next_id = nil
			templ = @template_loader.get_template id
			if templ
				scope.locale = @locale_loader.get_locale scope.lang, id
				scope.current_template = id
				scope.next_template = nil
				body = Haml::Engine.new(templ, :encoding => 'utf-8').render(scope, locals) { body }.force_encoding('utf-8')
				scope.current_template = nil
				next_id = scope.next_template if scope.respond_to?(:next_template)
			end
			if 'autohandler' === id_a.last
				base_a.pop
				break if base_a.empty?
			end
			id_a = next_id ? next_id.split('/') : (base_a + ['autohandler'])
		end
		body
	end
end

TJ = TemplateJuggler

