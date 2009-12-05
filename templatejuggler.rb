%w[haml].each {|r| require r}

class TemplateJuggler

	# Экземпляр этого класса работает загрузчиком шаблонов, считая, что id шаблона соответствует именем файла
	# (с подкаталогами) внутри заданного каталога.
	class SimpleLoader
		attr_accessor :views_dir
		def initialize path='./views'
			@views_dir = path
		end
		def get id
			path = File.join(@views_dir, "#{id}.haml")
			File::exists?(path) && File::readable?(path) ? File::open(path, 'r'){ |file| file.read } : nil
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
		def initialize machine=nil
			@callback_machine = machine
		end
		def call id, args={}
			@callback_machine.render id, args if callback_machine.respond_to?(:render)
		end
	end

	# Объект, имеющий метод get и возвращающий шаблон по заданному id.
	# Для самой TJ не важно, где именно хранятся шаблоны. 
	attr_accessor :loader
	def initialize loader=nil
		@loader = loader || SimpleLoader.new
	end
	def render id, args={}
		id = id.to_s # id -- строка, имеющая вид полного пути ( "/aaa/bbb/ccc/fff" )
		id_a = id.split '/'
		base_a = id_a.dup
		base_a.pop
		scope = args[:scope] || Scope.new(self)
		locals = args[:locals] || {}
		body = ''
		loop do
			id = id_a.join('/')
			next_id = nil
			templ = @loader.get id
		#	p id
			if templ
				scope.current_template = id
				scope.next_template = nil
				body = Haml::Engine.new(templ).render(scope, locals) { body }
				scope.current_template = nil
				next_id = scope.next_template if scope.respond_to?(:next_template)
			end
			if 'autohandler' === id_a.last
				base_a.pop
				break if base_a.empty?
			end
			if next_id
				id_a = next_id.split '/'
			else
				id_a = base_a + ['autohandler']
			end
		end
		body
	end
end

TJ = TemplateJuggler


