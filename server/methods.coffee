wrap = (resource, method, params) ->
  Stripe = StripeAPI(Billing.settings.secretKey)
  call = Async.wrap Stripe[resource], method
  try
    call params
  catch e
    console.error e
    throw new Meteor.Error 500, e.message


Meteor.methods

  #
  # Creates stripe customer then updates the user document with the stripe customerId and cardId
  #
  createCustomer: (userId, card) ->
    console.log 'Creating customer for', userId
    user = BillingUser.first(_id: userId)
    unless user then throw new Meteor.Error 404, "User not found.  Customer cannot be created."

    Stripe = StripeAPI(Billing.settings.secretKey)
    create = Async.wrap Stripe.customers, 'create'
    try
      email = if user.emails then user.emails[0].address else ''
      customer = create email: email, card: card.id
      Meteor.users.update _id: user._id,
        $set: 'billing.customerId': customer.id, 'billing.cardId': customer.default_card
    catch e
      console.error e
      throw new Meteor.Error 500, e.message

  #
  # Create a card on a customer and set cardId
  #
  createCard: (userId, card) ->
    console.log 'Creating card for', userId
    user = BillingUser.first(_id: userId)
    unless user then throw new Meteor.Error 404, "User not found.  Card cannot be created."

    Stripe = StripeAPI(Billing.settings.secretKey)
    createCard = Async.wrap Stripe.customers, 'createCard'
    try
      card = createCard user.billing.customerId, card: card.id
      user.update('billing.cardId': card.id)
    catch e
      console.error e
      throw new Meteor.Error 500, e.message

  #
  #  Get details about a customers credit card
  #
  retrieveCard: (customerId, cardId) ->
    console.log "Retrieving card #{cardId} for #{customerId}"
    user = BillingUser.first 'billing.customerId': customerId
    unless user then throw new Meteor.Error 404, "User not found.  Cannot retrieve card info."

    Stripe = StripeAPI(Billing.settings.secretKey)
    retrieveCard = Async.wrap Stripe.customers, 'retrieveCard'
    try
      retrieveCard user.billing.customerId, user.billing.cardId
    catch e
      console.log e
      throw new Meteor.Error 500, e.message    

  #
  # Delete a card on customer and unset cardId
  #
  deleteCard: (userId, cardId) ->
    console.log 'Deleting card for', userId
    user = BillingUser.first(_id: userId)
    unless user then throw new Meteor.Error 404, "User not found.  Card cannot be deleted."

    Stripe = StripeAPI(Billing.settings.secretKey)
    deleteCard = Async.wrap Stripe.customers, 'deleteCard'
    try
      card = deleteCard user.billing.customerId, cardId
      user.update('billing.cardId': null)
    catch e
      console.error e
      throw new Meteor.Error 500, e.message

  #
  # Create a single one-time charge
  #
  createCharge: (params) ->
    console.log "Creating charge"
    wrap 'charges', 'create', params

  #
  # List charges with any filters applied
  #
  listCharges: (params) ->
    console.log "Getting past charges"
    wrap 'charges', 'list', params
    

  #
  # Update stripe subscription for user with provided plan and quantitiy
  #
  updateSubscription: (userId, params) ->
    console.log 'Updating subscription for', userId
    user = BillingUser.first(_id: userId)
    if user then customerId = user.billing.customerId
    unless user and customerId then new Meteor.Error 404, "User not found.  Subscription cannot be updated."
    if user.billing.waiveFees or user.billing.admin then return

    Stripe = StripeAPI(Billing.settings.secretKey)
    updateSubscription = Async.wrap Stripe.customers, 'updateSubscription'
    try
      subscription = updateSubscription customerId, params
      Meteor.users.update _id: userId,
        $set: 'billing.subscriptionId': subscription.id, 'billing.planId' : params.plan
    catch e
      console.error e
      throw new Meteor.Error 500, e.message

  #
  # Manually cancels the stripe subscription for the provided customerId
  #
  cancelSubscription: (customerId) ->
    console.log 'Canceling subscription for', customerId
    user = BillingUser.first('billing.customerId': customerId)
    unless user then new Meteor.Error 404, "User not found.  Subscription cannot be canceled."

    Stripe = StripeAPI(Billing.settings.secretKey)
    cancelSubscription = Async.wrap Stripe.customers, 'cancelSubscription'
    try
      cancelSubscription customerId
    catch e
      console.error e
      throw new Meteor.Error 500, e.message


  #
  # A subscription was deleted from Stripe, remove subscriptionId and card from user.
  #
  subscriptionDeleted: (customerId) ->
    console.log 'Subscription deleted for', customerId
    user = BillingUser.first('billing.customerId': customerId)
    unless user then new Meteor.Error 404, "User not found.  Subscription cannot be deleted."
    user.update 'billing.subscriptionId': null, 'billing.planId': null


  #
  # Get past invoices
  #
  getInvoices: ->
    console.log 'Getting past invoices for', Meteor.userId()
    Stripe = StripeAPI(Billing.settings.secretKey)
    if Meteor.user().billing
      customerId = Meteor.user().billing.customerId
      try
        invoices = Async.wrap(Stripe.invoices, 'list')(customer: customerId)
      catch e
        console.error e
        throw new Meteor.Error 500, e.message
      invoices
    else
      throw new Meteor.Error 404, "No subscription"
    

  #
  # Get next invoice
  #
  getUpcomingInvoice: ->    
    console.log 'Getting upcoming invoice for', Meteor.userId()    
    Stripe = StripeAPI(Billing.settings.secretKey)
    if Meteor.user().billing
      customerId = Meteor.user().billing.customerId
      try
        invoice = Async.wrap(Stripe.invoices, 'retrieveUpcoming')(customerId)
      catch e
        console.error e
        throw new Meteor.Error 500, e.message
      invoice
    else
      throw new Meteor.Error 404, "No subscription"