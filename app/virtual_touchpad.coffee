###
Virtual gamepad class
###

fs = require 'fs'
ioctl = require 'ioctl'
uinput = require '../lib/uinput'
uinputStructs = require '../lib/uinput_structs'
config = require '../config.json'
winston = require('winston')
winston.level = config.logLevel

class virtual_touchpad

  constructor: () ->

  connect: (callback, error, retry=0) ->
    fs.open '/dev/uinput', 'w+', (err, fd) =>
      if err
        error err
      else
        @fd = fd

        # Init buttons
        ioctl @fd, uinput.UI_SET_EVBIT, uinput.EV_KEY
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_LEFT
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_RIGHT
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_MIDDLE
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_A
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_B
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_X
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_Y
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_TL
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_TR
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_START
        ioctl @fd, uinput.UI_SET_KEYBIT, uinput.BTN_SELECT
        # Init absolute directions
        ioctl @fd, uinput.UI_SET_EVBIT, uinput.EV_ABS
        ioctl @fd, uinput.UI_SET_ABSBIT, uinput.ABS_X
        ioctl @fd, uinput.UI_SET_ABSBIT, uinput.ABS_Y
        # Init relative directions
        ioctl @fd, uinput.UI_SET_EVBIT, uinput.EV_REL
        ioctl @fd, uinput.UI_SET_RELBIT, uinput.REL_X
        ioctl @fd, uinput.UI_SET_RELBIT, uinput.REL_Y
        ioctl @fd, uinput.UI_SET_RELBIT, uinput.REL_WHEEL

        uidev = new uinputStructs.uinput_user_dev
        uidev_buffer = uidev.ref()
        uidev_buffer.fill(0)
        uidev.name = Array.from("Virtual touchpad")
        uidev.id.bustype = uinput.BUS_USB
        uidev.id.vendor = 0x3
        uidev.id.product = 0x5
        uidev.id.version = 1

        uidev.absmax[uinput.ABS_X] = 255
        uidev.absmin[uinput.ABS_X] = 0
        uidev.absfuzz[uinput.ABS_X] = 0
        uidev.absflat[uinput.ABS_X] = 15

        uidev.absmax[uinput.ABS_Y] = 255
        uidev.absmin[uinput.ABS_Y] = 0
        uidev.absfuzz[uinput.ABS_Y] = 0
        uidev.absflat[uinput.ABS_Y] = 15

        fs.write @fd, uidev_buffer, 0, uidev_buffer.length, null, (err) =>
          if err
            winston.log 'warn', "Error on init touchpad write:\n", err
            error err
          else
            try
              ioctl @fd, uinput.UI_DEV_CREATE
              callback()
            catch err
              winston.log 'error', "Error on touchpad create dev:\n", err
              fs.close @fd
              @fd = undefined
              if retry < 5
                winston.log 'info', "Retry to create touchpad"
                @connect callback, error, retry+1
              else
                winston.log 'error', "Gave up on creating device"
                error err

  disconnect: (callback) ->
    if @fd
      ioctl @fd, uinput.UI_DEV_DESTROY
      fs.close @fd
      @fd = undefined
      callback()

  sendEvent: (event) ->
    if @fd
      ev = new uinputStructs.input_event
      ev.type = event.type
      ev.code = event.code
      ev.value = event.value
      ev.time.tv_sec = Math.round(Date.now() / 1000)
      ev.time.tv_usec = Math.round(Date.now() % 1000 * 1000)
      ev_buffer = ev.ref()

      ev_end = new uinputStructs.input_event
      ev_end.type = 0
      ev_end.code = 0
      ev_end.value = 0
      ev_end.time.tv_sec = Math.round(Date.now() / 1000)
      ev_end.time.tv_usec = Math.round(Date.now() % 1000 * 1000)
      ev_end_buffer = ev_end.ref()

      try
        fs.writeSync @fd, ev_buffer, 0, ev_buffer.length, null
      catch err
        winston.log 'error', "Error on writing ev_buffer"
        throw err
      try
        fs.writeSync @fd, ev_end_buffer, 0, ev_end_buffer.length, null
      catch err
        winston.log 'error', "Error on writing ev_end_buffer"
        throw err


module.exports = virtual_touchpad
