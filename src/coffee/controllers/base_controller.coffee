###
Crafting Guide - base_controller.coffee

Copyright (c) 2014-2015 by Redwood Labs
All rights reserved.
###

views   = require '../views'
{Event} = require '../constants'

########################################################################################################################

module.exports = class BaseController extends Backbone.View

    constructor: (options={})->
        options.useAnimations ?= true
        @tryRefresh = _.debounce @_tryRefresh, 100

        @_model         = null
        @_rendered      = false
        @_parent        = options.parent
        @_children      = []
        @_useAnimations = options.useAnimations

        @_loadTemplate options.templateName
        super options

    # Public Methods ###############################################################################

    addChild: (Controller, atSelector, options={})->
        options.el = @$(atSelector)[0]
        options.parent = this

        child = new Controller options
        child.render options
        @_children.push child
        return child

    hide: (args...)->
        {$el, callback} = @_resolveShowHideArgs args

        $el.addClass 'hideable' unless $el.hasClass 'hideable'

        logger.verbose => "#{this} is hiding #{$el.selector}"
        if $el.hasClass('hiding') or $el.hasClass('hidden')
            _.defer => callback this
        else
            $el.off Event.transitionEnd
            $el.one Event.transitionEnd, =>
                $el.addClass 'hidden'
                $el.removeClass 'hiding'
                callback this

            $el.addClass 'hiding'

    refresh: ->
        logger.verbose => "#{this} refreshing"

    remove: ->
        if @_useAnimations
            @hide =>
                logger.verbose => "#{this} is removing its element from the DOM"
                @$el.remove()
        else
            @$el.remove()

    routeLinkClick: (event)->
        event.preventDefault()
        href = $(event.target).attr 'href'
        href ?= $(event.currentTarget).attr 'href'
        logger.info "Re-routing link to internal navigation: #{href}"

        if href? and href.match /^http/
            window.location.href = href
        else
            router.navigate href, trigger:true

    show: (args...)->
        {$el, callback} = @_resolveShowHideArgs args

        $el.addClass 'hideable' unless $el.hasClass 'hideable'

        logger.verbose => "#{this} is showing #{$el.selector}"
        if $el.hasClass('hiding') or $el.hasClass('hidden')
            $el.off Event.transitionEnd
            $el.one Event.transitionEnd, => callback this
            $el.removeClass 'hiding'
            $el.removeClass 'hidden'
        else
            _.defer => callback this

    unrender: ->
        @undelegateEvents()
        @$el.empty()

    # Event Methods ################################################################################

    onDidModelChange: ->
        @tryRefresh()

    onDidModelSync: ->
        @tryRefresh()

    onWillRender: -> # do nothing

    onDidRender: ->
        @tryRefresh()

    onWillShow: -> # do nothing

    onDidShow: -> # do nothing

    onWillChangeModel: (oldModel, newModel)->
        if oldModel?.on?
            @stopListening oldModel
        if newModel?.on?
            @listenTo newModel, 'sync', (e)=> @onDidModelSync e
            @listenTo newModel, 'change', (e)=> @onDidModelChange e
        return newModel

    # Property Methods #############################################################################

    getModel: ->
        return @_model

    setModel: (newModel)->
        return if @model is newModel

        newModel = @onWillChangeModel @_model, newModel
        @_model = newModel
        @tryRefresh()

    isRendered: ->
        return @_rendered

    getUser: ->
        return @_user

    setUser: (user)->
        @_user = user
        @tryRefresh()

    Object.defineProperties @prototype,
        model:    {get:@prototype.getModel,  set:@prototype.setModel}
        rendered: {get:@prototype.isRendered }
        user:     {get:@prototype.user,      set:@prototype.setUser}

    # Backbone.View Overrides ######################################################################

    events: ->
        return {}

    render: (options={})->
        options.force ?= false
        options.show ?= true
        return this unless not @_rendered or options.force

        if not @_template?
            logger.error => "Default render called for #{@constructor.name} without a template"
            return this

        data = (@model?.toHash? and @model.toHash()) or @model or {}
        logger.verbose => "#{this} rendering with data: #{data}"
        $renderedEl = $($(@_template(data))[0])

        @onWillRender()
        @hide() if @_useAnimations

        @unrender()
        @$el.append $renderedEl.children()
        @$el.addClass $renderedEl.attr 'class'
        @$el.data $renderedEl.data()
        @delegateEvents()
        @show() if options.show and @_useAnimations

        @_rendered = true
        @onDidRender()

        return this

    # Object Overrides #############################################################################

    toString: ->
        return "#{@constructor.name}.#{@cid}"

    # Private Methods ##############################################################################

    _loadTemplate: (templateName)->
        if templateName?
            @_template = views[templateName]

    _resolveShowHideArgs: (args)->
        if args.length is 0
            return $el:@$el, callback:->
        else if args.length is 1
            if _.isFunction args[0]
                return $el:@$el, callback:args[0]
            else
                return $el:args[0], callback:->
        else if args.length is 2
            return $el:args[0], callback:args[1]
        else
            throw new Error "expected to get 0, 1, or 2 args"

    _tryRefresh: ->
        return unless @_rendered
        @refresh()
